//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//
// SNIHandlerTests+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension SNIHandlerTest {
    @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
    static var allTests: [(String, (SNIHandlerTest) -> () throws -> Void)] {
        [
            ("testLibre227NoSNIDripFeed", testLibre227NoSNIDripFeed),
            ("testLibre227WithSNIDripFeed", testLibre227WithSNIDripFeed),
            ("testOpenSSL102NoSNIDripFeed", testOpenSSL102NoSNIDripFeed),
            ("testOpenSSL102WithSNIDripFeed", testOpenSSL102WithSNIDripFeed),
            ("testCurlSecureTransportDripFeed", testCurlSecureTransportDripFeed),
            ("testSafariDripFeed", testSafariDripFeed),
            ("testChromeDripFeed", testChromeDripFeed),
            ("testFirefoxDripFeed", testFirefoxDripFeed),
            ("testLibre227NoSNIBlast", testLibre227NoSNIBlast),
            ("testLibre227WithSNIBlast", testLibre227WithSNIBlast),
            ("testOpenSSL102NoSNIBlast", testOpenSSL102NoSNIBlast),
            ("testOpenSSL102WithSNIBlast", testOpenSSL102WithSNIBlast),
            ("testCurlSecureTransportBlast", testCurlSecureTransportBlast),
            ("testSafariBlast", testSafariBlast),
            ("testChromeBlast", testChromeBlast),
            ("testFirefoxBlast", testFirefoxBlast),
            ("testIgnoresUnknownRecordTypes", testIgnoresUnknownRecordTypes),
            ("testIgnoresUnknownTlsVersions", testIgnoresUnknownTlsVersions),
            ("testIgnoresNonClientHelloHandshakeMessages", testIgnoresNonClientHelloHandshakeMessages),
            ("testIgnoresInvalidHandshakeLength", testIgnoresInvalidHandshakeLength),
            ("testIgnoresInvalidCipherSuiteLength", testIgnoresInvalidCipherSuiteLength),
            ("testIgnoresInvalidCompressionLength", testIgnoresInvalidCompressionLength),
            ("testIgnoresInvalidExtensionLength", testIgnoresInvalidExtensionLength),
            ("testIgnoresInvalidIndividualExtensionLength", testIgnoresInvalidIndividualExtensionLength),
            ("testIgnoresUnknownNameType", testIgnoresUnknownNameType),
            ("testIgnoresInvalidNameLength", testIgnoresInvalidNameLength),
            ("testIgnoresInvalidNameExtensionLength", testIgnoresInvalidNameExtensionLength),
            ("testLudicrouslyTruncatedPacket", testLudicrouslyTruncatedPacket),
            ("testFuzzingInputOne", testFuzzingInputOne)
        ]
    }
}
