//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import NIOHTTP1
import XCTest

private class MessageEndHandler<Head: Equatable, Body: Equatable>: ChannelInboundHandler {
    typealias InboundIn = HTTPPart<Head, Body>

    var seenEnd = false
    var seenBody = false
    var seenHead = false

    func channelRead(context _: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head:
            XCTAssertFalse(self.seenHead)
            self.seenHead = true
        case .body:
            XCTAssertFalse(self.seenBody)
            self.seenBody = true
        case .end:
            XCTAssertFalse(self.seenEnd)
            self.seenEnd = true
        }
    }
}

/// Tests for the HTTP decoder's handling of message body framing.
///
/// Mostly tests assertions in [RFC 7230 § 3.3.3](https://tools.ietf.org/html/rfc7230#section-3.3.3).
class HTTPDecoderLengthTest: XCTestCase {
    private var channel: EmbeddedChannel!
    private var loop: EmbeddedEventLoop {
        self.channel.embeddedEventLoop
    }

    override func setUp() {
        self.channel = EmbeddedChannel()
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.channel?.finish(acceptAlreadyClosed: true))
        self.channel = nil
    }

    /// The mechanism by which EOF is being sent.
    enum EOFMechanism {
        case channelInactive
        case halfClosure
    }

    /// The various header fields that can be used to frame a response.
    enum FramingField {
        case contentLength
        case transferEncoding
        case neither
    }

    private func assertSemanticEOFOnChannelInactiveResponse(version: HTTPVersion, how eofMechanism: EOFMechanism) throws {
        class ChannelInactiveHandler: ChannelInboundHandler {
            typealias InboundIn = HTTPClientResponsePart
            var response: HTTPResponseHead?
            var receivedEnd = false
            var eof = false
            var body: [UInt8]?
            private let eofMechanism: EOFMechanism

            init(_ eofMechanism: EOFMechanism) {
                self.eofMechanism = eofMechanism
            }

            func channelRead(context _: ChannelHandlerContext, data: NIOAny) {
                switch unwrapInboundIn(data) {
                case let .head(h):
                    self.response = h
                case .end:
                    self.receivedEnd = true
                case var .body(b):
                    XCTAssertNil(self.body)
                    self.body = b.readBytes(length: b.readableBytes)!
                }
            }

            func channelInactive(context _: ChannelHandlerContext) {
                if case .channelInactive = self.eofMechanism {
                    XCTAssert(self.receivedEnd, "Received channelInactive before response end!")
                    self.eof = true
                } else {
                    XCTAssert(self.eof, "Did not receive .inputClosed")
                }
            }

            func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
                guard case .halfClosure = self.eofMechanism else {
                    XCTFail("Got half closure when not expecting it")
                    return
                }

                guard let evt = event as? ChannelEvent, case .inputClosed = evt else {
                    context.fireUserInboundEventTriggered(event)
                    return
                }

                XCTAssert(self.receivedEnd, "Received inputClosed before response end!")
                self.eof = true
            }
        }

        XCTAssertNoThrow(try self.channel.pipeline.addHandler(HTTPRequestEncoder()).wait())
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPResponseDecoder())).wait())

        let handler = ChannelInactiveHandler(eofMechanism)
        XCTAssertNoThrow(try channel.pipeline.addHandler(handler).wait())

        // Prime the decoder with a GET and consume it.
        XCTAssertTrue(try self.channel.writeOutbound(HTTPClientRequestPart.head(HTTPRequestHead(version: version, method: .GET, uri: "/"))).isFull)
        XCTAssertNoThrow(XCTAssertNotNil(try self.channel.readOutbound(as: ByteBuffer.self)))

        // We now want to send a HTTP/1.1 response. This response has no content-length, no transfer-encoding,
        // is not a response to a HEAD request, is not a 2XX response to CONNECT, and is not 1XX, 204, or 304.
        // That means, per RFC 7230 § 3.3.3, the body is framed by EOF. Because this is a response, that EOF
        // may be transmitted by channelInactive.
        let response = "HTTP/\(version.major).\(version.minor) 200 OK\r\nServer: example\r\n\r\n"
        XCTAssertNoThrow(try self.channel.writeInbound(IOData.byteBuffer(self.channel.allocator.buffer(string: response))))

        // We should have a response but no body.
        XCTAssertNotNil(handler.response)
        XCTAssertNil(handler.body)
        XCTAssertFalse(handler.receivedEnd)
        XCTAssertFalse(handler.eof)

        // Send a body chunk. This should be immediately passed on. Still no end or EOF.
        XCTAssertNoThrow(try self.channel.writeInbound(IOData.byteBuffer(self.channel.allocator.buffer(string: "some body data"))))
        XCTAssertNotNil(handler.response)
        XCTAssertEqual(handler.body!, Array("some body data".utf8))
        XCTAssertFalse(handler.receivedEnd)
        XCTAssertFalse(handler.eof)

        // Now we send EOF. This should cause a response end. The handler will enforce ordering.
        if case .halfClosure = eofMechanism {
            channel.pipeline.fireUserInboundEventTriggered(ChannelEvent.inputClosed)
        } else {
            self.channel.pipeline.fireChannelInactive()
        }
        XCTAssertNotNil(handler.response)
        XCTAssertEqual(handler.body!, Array("some body data".utf8))
        XCTAssertTrue(handler.receivedEnd)
        XCTAssertTrue(handler.eof)

        XCTAssertTrue(try self.channel.finish().isClean)
    }

    func testHTTP11SemanticEOFOnChannelInactive() throws {
        try self.assertSemanticEOFOnChannelInactiveResponse(version: .http1_1, how: .channelInactive)
    }

    func testHTTP10SemanticEOFOnChannelInactive() throws {
        try self.assertSemanticEOFOnChannelInactiveResponse(version: .http1_0, how: .channelInactive)
    }

    func testHTTP11SemanticEOFOnHalfClosure() throws {
        try self.assertSemanticEOFOnChannelInactiveResponse(version: .http1_1, how: .halfClosure)
    }

    func testHTTP10SemanticEOFOnHalfClosure() throws {
        try self.assertSemanticEOFOnChannelInactiveResponse(version: .http1_0, how: .halfClosure)
    }

    private func assertIgnoresLengthFields(requestMethod: HTTPMethod,
                                           responseStatus: HTTPResponseStatus,
                                           responseFramingField: FramingField) throws
    {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(HTTPRequestEncoder()).wait())
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPResponseDecoder())).wait())

        let handler = MessageEndHandler<HTTPResponseHead, ByteBuffer>()
        XCTAssertNoThrow(try channel.pipeline.addHandler(handler).wait())

        // Prime the decoder with a request and consume it.
        XCTAssertTrue(try self.channel.writeOutbound(HTTPClientRequestPart.head(HTTPRequestHead(version: .http1_1,
                                                                                                method: requestMethod,
                                                                                                uri: "/"))).isFull)
        XCTAssertNoThrow(XCTAssertNotNil(try self.channel.readOutbound(as: ByteBuffer.self)))

        // We now want to send a HTTP/1.1 response. This response may contain some length framing fields that RFC 7230 says MUST
        // be ignored.
        var response = self.channel.allocator.buffer(capacity: 256)
        response.writeString("HTTP/1.1 \(responseStatus.code) \(responseStatus.reasonPhrase)\r\nServer: example\r\n")

        switch responseFramingField {
        case .contentLength:
            response.writeStaticString("Content-Length: 16\r\n")
        case .transferEncoding:
            response.writeStaticString("Transfer-Encoding: chunked\r\n")
        case .neither:
            break
        }
        response.writeStaticString("\r\n")

        XCTAssertNoThrow(try self.channel.writeInbound(IOData.byteBuffer(response)))

        // We should have a response, no body, and immediately see EOF.
        XCTAssert(handler.seenHead)
        XCTAssertFalse(handler.seenBody)
        XCTAssert(handler.seenEnd)

        XCTAssertTrue(try self.channel.finish().isClean)
    }

    func testIgnoresTransferEncodingFieldOnCONNECTResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .CONNECT, responseStatus: .ok, responseFramingField: .transferEncoding)
    }

    func testIgnoresContentLengthFieldOnCONNECTResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .CONNECT, responseStatus: .ok, responseFramingField: .contentLength)
    }

    func testEarlyFinishWithoutLengthAtAllOnCONNECTResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .CONNECT, responseStatus: .ok, responseFramingField: .neither)
    }

    func testIgnoresTransferEncodingFieldOnHEADResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .HEAD, responseStatus: .ok, responseFramingField: .transferEncoding)
    }

    func testIgnoresContentLengthFieldOnHEADResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .HEAD, responseStatus: .ok, responseFramingField: .contentLength)
    }

    func testEarlyFinishWithoutLengthAtAllOnHEADResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .HEAD, responseStatus: .ok, responseFramingField: .neither)
    }

    func testIgnoresTransferEncodingFieldOn1XXResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET,
                                           responseStatus: .custom(code: 103, reasonPhrase: "Early Hints"),
                                           responseFramingField: .transferEncoding)
    }

    func testIgnoresContentLengthFieldOn1XXResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET,
                                           responseStatus: .custom(code: 103, reasonPhrase: "Early Hints"),
                                           responseFramingField: .contentLength)
    }

    func testEarlyFinishWithoutLengthAtAllOn1XXResponses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET,
                                           responseStatus: .custom(code: 103, reasonPhrase: "Early Hints"),
                                           responseFramingField: .neither)
    }

    func testIgnoresTransferEncodingFieldOn204Responses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET, responseStatus: .noContent, responseFramingField: .transferEncoding)
    }

    func testIgnoresContentLengthFieldOn204Responses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET, responseStatus: .noContent, responseFramingField: .contentLength)
    }

    func testEarlyFinishWithoutLengthAtAllOn204Responses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET, responseStatus: .noContent, responseFramingField: .neither)
    }

    func testIgnoresTransferEncodingFieldOn304Responses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET, responseStatus: .notModified, responseFramingField: .transferEncoding)
    }

    func testIgnoresContentLengthFieldOn304Responses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET, responseStatus: .notModified, responseFramingField: .contentLength)
    }

    func testEarlyFinishWithoutLengthAtAllOn304Responses() throws {
        try self.assertIgnoresLengthFields(requestMethod: .GET, responseStatus: .notModified, responseFramingField: .neither)
    }

    private func assertRequestTransferEncodingInError(transferEncodingHeader: String) throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder())).wait())

        let handler = MessageEndHandler<HTTPRequestHead, ByteBuffer>()
        XCTAssertNoThrow(try channel.pipeline.addHandler(handler).wait())

        // Send a GET with the appropriate Transfer Encoding header.
        XCTAssertThrowsError(try self.channel.writeInbound(self.channel.allocator.buffer(string: "POST / HTTP/1.1\r\nTransfer-Encoding: \(transferEncodingHeader)\r\n\r\n"))) { error in
            XCTAssertEqual(error as? HTTPParserError, .unknown)
        }
    }

    func testMultipleTEWithChunkedLastWorksFine() throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder())).wait())

        let handler = MessageEndHandler<HTTPRequestHead, ByteBuffer>()
        XCTAssertNoThrow(try channel.pipeline.addHandler(handler).wait())

        // Send a GET with the appropriate Transfer Encoding header.
        XCTAssertNoThrow(try self.channel.writeInbound(self.channel.allocator.buffer(string: "POST / HTTP/1.1\r\nTransfer-Encoding: gzip, chunked\r\n\r\n0\r\n\r\n")))

        // We should have a request, no body, and immediately see end of request.
        XCTAssert(handler.seenHead)
        XCTAssertFalse(handler.seenBody)
        XCTAssert(handler.seenEnd)

        XCTAssertTrue(try self.channel.finish().isClean)
    }

    func testMultipleTEWithChunkedFirstHasNoBodyOnRequest() throws {
        try self.assertRequestTransferEncodingInError(transferEncodingHeader: "chunked, gzip")
    }

    func testMultipleTEWithChunkedInTheMiddleHasNoBodyOnRequest() throws {
        try self.assertRequestTransferEncodingInError(transferEncodingHeader: "gzip, chunked, deflate")
    }

    private func assertResponseTransferEncodingHasBodyTerminatedByEOF(transferEncodingHeader: String, eofMechanism: EOFMechanism) throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(HTTPRequestEncoder()).wait())
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPResponseDecoder())).wait())

        let handler = MessageEndHandler<HTTPResponseHead, ByteBuffer>()
        XCTAssertNoThrow(try channel.pipeline.addHandler(handler).wait())

        // Prime the decoder with a request and consume it.
        XCTAssertTrue(try self.channel.writeOutbound(HTTPClientRequestPart.head(HTTPRequestHead(version: .http1_1,
                                                                                                method: .GET,
                                                                                                uri: "/"))).isFull)
        XCTAssertNoThrow(XCTAssertNotNil(try self.channel.readOutbound(as: ByteBuffer.self)))

        // Send a 200 with the appropriate Transfer Encoding header. We should see the request,
        // but no body or end.
        XCTAssertNoThrow(try self.channel.writeInbound(self.channel.allocator.buffer(string: "HTTP/1.1 200 OK\r\nTransfer-Encoding: \(transferEncodingHeader)\r\n\r\n")))
        XCTAssert(handler.seenHead)
        XCTAssertFalse(handler.seenBody)
        XCTAssertFalse(handler.seenEnd)

        // Now send body. Note that this is *not* chunk encoded. We should also see a body.
        XCTAssertNoThrow(try self.channel.writeInbound(self.channel.allocator.buffer(string: "caribbean")))
        XCTAssert(handler.seenHead)
        XCTAssert(handler.seenBody)
        XCTAssertFalse(handler.seenEnd)

        // Now send EOF. This should send the end as well.
        if case .halfClosure = eofMechanism {
            channel.pipeline.fireUserInboundEventTriggered(ChannelEvent.inputClosed)
        } else {
            self.channel.pipeline.fireChannelInactive()
        }
        XCTAssert(handler.seenHead)
        XCTAssert(handler.seenBody)
        XCTAssert(handler.seenEnd)

        XCTAssertTrue(try self.channel.finish().isClean)
    }

    private func assertResponseTransferEncodingHasBodyTerminatedByEndOfChunk(transferEncodingHeader: String, eofMechanism: EOFMechanism) throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(HTTPRequestEncoder()).wait())
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPResponseDecoder())).wait())

        let handler = MessageEndHandler<HTTPResponseHead, ByteBuffer>()
        XCTAssertNoThrow(try channel.pipeline.addHandler(handler).wait())

        // Prime the decoder with a request and consume it.
        XCTAssertTrue(try self.channel.writeOutbound(HTTPClientRequestPart.head(HTTPRequestHead(version: .http1_1,
                                                                                                method: .GET,
                                                                                                uri: "/"))).isFull)
        XCTAssertNoThrow(XCTAssertNotNil(try self.channel.readOutbound(as: ByteBuffer.self)))

        // Send a 200 with the appropriate Transfer Encoding header. We should see the request.
        XCTAssertNoThrow(try self.channel.writeInbound(self.channel.allocator.buffer(string: "HTTP/1.1 200 OK\r\nTransfer-Encoding: \(transferEncodingHeader)\r\n\r\n")))
        XCTAssert(handler.seenHead)
        XCTAssertFalse(handler.seenBody)
        XCTAssertFalse(handler.seenEnd)

        // Now send body. Note that this *is* chunk encoded. We should also see a body.
        XCTAssertNoThrow(try self.channel.writeInbound(self.channel.allocator.buffer(string: "9\r\ncaribbean\r\n")))
        XCTAssert(handler.seenHead)
        XCTAssert(handler.seenBody)
        XCTAssertFalse(handler.seenEnd)

        // Now send EOF. This should error, as we're expecting the end chunk.
        if case .halfClosure = eofMechanism {
            channel.pipeline.fireUserInboundEventTriggered(ChannelEvent.inputClosed)
        } else {
            self.channel.pipeline.fireChannelInactive()
        }

        XCTAssert(handler.seenHead)
        XCTAssert(handler.seenBody)
        XCTAssertFalse(handler.seenEnd)

        XCTAssertThrowsError(try self.channel.throwIfErrorCaught()) { error in
            XCTAssertEqual(error as? HTTPParserError, .invalidEOFState)
        }

        XCTAssertTrue(try self.channel.finish().isClean)
    }

    func testMultipleTEWithChunkedLastHasEOFBodyOnResponseWithChannelInactive() throws {
        try self.assertResponseTransferEncodingHasBodyTerminatedByEndOfChunk(transferEncodingHeader: "gzip, chunked", eofMechanism: .channelInactive)
    }

    func testMultipleTEWithChunkedFirstHasEOFBodyOnResponseWithChannelInactive() throws {
        // Here http_parser is right, and this is EOF terminated.
        try self.assertResponseTransferEncodingHasBodyTerminatedByEOF(transferEncodingHeader: "chunked, gzip", eofMechanism: .channelInactive)
    }

    func testMultipleTEWithChunkedInTheMiddleHasEOFBodyOnResponseWithChannelInactive() throws {
        // Here http_parser is right, and this is EOF terminated.
        try self.assertResponseTransferEncodingHasBodyTerminatedByEOF(transferEncodingHeader: "gzip, chunked, deflate", eofMechanism: .channelInactive)
    }

    func testMultipleTEWithChunkedLastHasEOFBodyOnResponseWithHalfClosure() throws {
        try self.assertResponseTransferEncodingHasBodyTerminatedByEndOfChunk(transferEncodingHeader: "gzip, chunked", eofMechanism: .halfClosure)
    }

    func testMultipleTEWithChunkedFirstHasEOFBodyOnResponseWithHalfClosure() throws {
        // Here http_parser is right, and this is EOF terminated.
        try self.assertResponseTransferEncodingHasBodyTerminatedByEOF(transferEncodingHeader: "chunked, gzip", eofMechanism: .halfClosure)
    }

    func testMultipleTEWithChunkedInTheMiddleHasEOFBodyOnResponseWithHalfClosure() throws {
        // Here http_parser is right, and this is EOF terminated.
        try self.assertResponseTransferEncodingHasBodyTerminatedByEOF(transferEncodingHeader: "gzip, chunked, deflate", eofMechanism: .halfClosure)
    }

    func testRequestWithTEAndContentLengthErrors() throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder())).wait())

        // Send a GET with the invalid headers.
        let request = self.channel.allocator.buffer(string: "POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\nContent-Length: 4\r\n\r\n")
        XCTAssertThrowsError(try self.channel.writeInbound(request)) { error in
            XCTAssertEqual(HTTPParserError.unexpectedContentLength, error as? HTTPParserError)
        }

        // Must spin the loop.
        XCTAssertFalse(self.channel.isActive)
        self.channel.embeddedEventLoop.run()
    }

    func testResponseWithTEAndContentLengthErrors() throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(HTTPRequestEncoder()).wait())
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPResponseDecoder())).wait())

        // Prime the decoder with a request.
        XCTAssertTrue(try self.channel.writeOutbound(HTTPClientRequestPart.head(HTTPRequestHead(version: .http1_1,
                                                                                                method: .GET,
                                                                                                uri: "/"))).isFull)

        // Send a 200 OK with the invalid headers.
        let response = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Length: 4\r\n\r\n"
        XCTAssertThrowsError(try self.channel.writeInbound(self.channel.allocator.buffer(string: response))) { error in
            XCTAssertEqual(HTTPParserError.unexpectedContentLength, error as? HTTPParserError)
        }

        // Must spin the loop.
        XCTAssertFalse(self.channel.isActive)
        self.channel.embeddedEventLoop.run()
    }

    private func assertRequestWithInvalidCLErrors(contentLengthField: String) throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder())).wait())

        // Send a GET with the invalid headers.
        let request = "POST / HTTP/1.1\r\nContent-Length: \(contentLengthField)\r\n\r\n"
        XCTAssertThrowsError(try self.channel.writeInbound(self.channel.allocator.buffer(string: request))) { error in
            XCTAssert(HTTPParserError.unexpectedContentLength == error as? HTTPParserError ||
                HTTPParserError.invalidContentLength == error as? HTTPParserError)
        }

        // Must spin the loop.
        XCTAssertFalse(self.channel.isActive)
        self.channel.embeddedEventLoop.run()
    }

    func testRequestWithMultipleDifferentContentLengthsFails() throws {
        try self.assertRequestWithInvalidCLErrors(contentLengthField: "4, 5")
    }

    func testRequestWithMultipleDifferentContentLengthsOnDifferentLinesFails() throws {
        try self.assertRequestWithInvalidCLErrors(contentLengthField: "4\r\nContent-Length: 5")
    }

    func testRequestWithInvalidContentLengthFails() throws {
        try self.assertRequestWithInvalidCLErrors(contentLengthField: "pie")
    }

    func testRequestWithIdenticalContentLengthRepeatedErrors() throws {
        // This is another case where http_parser is, if not wrong, then aggressively interpreting
        // the spec. Regardless, we match it.
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder())).wait())

        // Send two POSTs with repeated content length, one with one field and one with two.
        // Both should error.
        let request = "POST / HTTP/1.1\r\nContent-Length: 4, 4\r\n\r\n"
        XCTAssertThrowsError(try self.channel.writeInbound(self.channel.allocator.buffer(string: request))) { error in
            XCTAssertEqual(HTTPParserError.invalidContentLength, error as? HTTPParserError)
        }

        // Must spin the loop.
        XCTAssertFalse(self.channel.isActive)
        self.channel.embeddedEventLoop.run()
    }

    func testRequestWithMultipleIdenticalContentLengthFieldsErrors() throws {
        // This is another case where http_parser is, if not wrong, then aggressively interpreting
        // the spec. Regardless, we match it.
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder())).wait())

        let request = "POST / HTTP/1.1\r\nContent-Length: 4\r\nContent-Length: 4\r\n\r\n"
        XCTAssertThrowsError(try self.channel.writeInbound(self.channel.allocator.buffer(string: request))) { error in
            XCTAssertEqual(HTTPParserError.unexpectedContentLength, error as? HTTPParserError)
        }

        // Must spin the loop.
        XCTAssertFalse(self.channel.isActive)
        self.channel.embeddedEventLoop.run()
    }

    func testRequestWithoutExplicitLengthIsZeroLength() throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder())).wait())

        let handler = MessageEndHandler<HTTPRequestHead, ByteBuffer>()
        XCTAssertNoThrow(try channel.pipeline.addHandler(handler).wait())

        // Send a POST without a length field of any kind. This should be a zero-length request,
        // so .end should come immediately.
        XCTAssertNoThrow(try self.channel.writeInbound(self.channel.allocator.buffer(string: "POST / HTTP/1.1\r\nHost: example.org\r\n\r\n")))
        XCTAssert(handler.seenHead)
        XCTAssertFalse(handler.seenBody)
        XCTAssert(handler.seenEnd)

        XCTAssertTrue(try self.channel.finish().isClean)
    }
}
