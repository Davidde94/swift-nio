//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2019 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIO

print("Please enter line to send to the server")
let line = readLine(strippingNewline: true)!

private final class EchoHandler: ChannelInboundHandler {
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    private var numBytes = 0

    private let remoteAddressInitializer: () throws -> SocketAddress

    init(remoteAddressInitializer: @escaping () throws -> SocketAddress) {
        self.remoteAddressInitializer = remoteAddressInitializer
    }

    public func channelActive(context: ChannelHandlerContext) {
        do {
            // Channel is available. It's time to send the message to the server to initialize the ping-pong sequence.

            // Get the server address.
            let remoteAddress = try remoteAddressInitializer()

            // Set the transmission data.
            let buffer = context.channel.allocator.buffer(string: line)
            self.numBytes = buffer.readableBytes

            // Forward the data.
            let envolope = AddressedEnvelope<ByteBuffer>(remoteAddress: remoteAddress, data: buffer)

            context.writeAndFlush(wrapOutboundOut(envolope), promise: nil)

        } catch {
            print("Could not resolve remote address")
        }
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = unwrapInboundIn(data)
        let byteBuffer = envelope.data

        self.numBytes -= byteBuffer.readableBytes

        if self.numBytes <= 0 {
            let string = String(buffer: byteBuffer)
            print("Received: '\(string)' back from the server, closing channel.")
            context.close(promise: nil)
        }
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}

// First argument is the program path
let arguments = CommandLine.arguments
let arg1 = arguments.dropFirst().first
let arg2 = arguments.dropFirst(2).first
let arg3 = arguments.dropFirst(3).first

// If only writing to the destination address, bind to local port 0 and address 0.0.0.0 or ::.
let defaultHost = "::1"
// If the server and the client are running on the same computer, these will need to differ from each other.
let defaultServerPort: Int = 9999
let defaultListeningPort: Int = 8888

enum ConnectTo {
    case ip(host: String, sendPort: Int, listeningPort: Int)
    case unixDomainSocket(sendPath: String, listeningPath: String)
}

let connectTarget: ConnectTo

switch (arg1, arg1.flatMap(Int.init), arg2, arg2.flatMap(Int.init), arg3.flatMap(Int.init)) {
case let (.some(h), .none, _, .some(sp), .some(lp)):
    /* We received three arguments (String Int Int), let's interpret that as a server host with a server port and a local listening port */
    connectTarget = .ip(host: h, sendPort: sp, listeningPort: lp)
case let (.some(sp), .none, .some(lp), .none, _):
    /* We received two arguments (String String), let's interpret that as sending socket path and listening socket path  */
    assert(sp != lp, "The sending and listening sockets should differ.")
    connectTarget = .unixDomainSocket(sendPath: sp, listeningPath: lp)
case let (_, .some(sp), _, .some(lp), _):
    /* We received two argument (Int Int), let's interpret that as the server port and a listening port on the default host. */
    connectTarget = .ip(host: defaultHost, sendPort: sp, listeningPort: lp)
default:
    connectTarget = .ip(host: defaultHost, sendPort: defaultServerPort, listeningPort: defaultListeningPort)
}

let remoteAddress = { () -> SocketAddress in
    switch connectTarget {
    case let .ip(host, sendPort, _):
        return try SocketAddress.makeAddressResolvingHost(host, port: sendPort)
    case let .unixDomainSocket(sendPath, _):
        return try SocketAddress(unixDomainSocketPath: sendPath)
    }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let bootstrap = DatagramBootstrap(group: group)
    // Enable SO_REUSEADDR.
    .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .channelInitializer { channel in
        channel.pipeline.addHandler(EchoHandler(remoteAddressInitializer: remoteAddress))
    }

defer {
    try! group.syncShutdownGracefully()
}

let channel = try { () -> Channel in
    switch connectTarget {
    case let .ip(host, _, listeningPort):
        return try bootstrap.bind(host: host, port: listeningPort).wait()
    case let .unixDomainSocket(_, listeningPath):
        return try bootstrap.bind(unixDomainSocketPath: listeningPath).wait()
    }
}()

// Will be closed after we echo-ed back to the server.
try channel.closeFuture.wait()

print("Client closed")
