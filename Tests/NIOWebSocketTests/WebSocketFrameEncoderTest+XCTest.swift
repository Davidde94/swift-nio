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
// WebSocketFrameEncoderTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension WebSocketFrameEncoderTest {
    @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
    static var allTests: [(String, (WebSocketFrameEncoderTest) -> () throws -> Void)] {
        [
            ("testBasicFrameEncoding", testBasicFrameEncoding),
            ("test16BitFrameLength", test16BitFrameLength),
            ("test64BitFrameLength", test64BitFrameLength),
            ("testEncodesEachReservedBitProperly", testEncodesEachReservedBitProperly),
            ("testEncodesExtensionDataCorrectly", testEncodesExtensionDataCorrectly),
            ("testMasksDataCorrectly", testMasksDataCorrectly),
            ("testFrameEncoderReusesHeaderBufferWherePossible", testFrameEncoderReusesHeaderBufferWherePossible),
            ("testFrameEncoderCanPrependHeaderToApplicationBuffer", testFrameEncoderCanPrependHeaderToApplicationBuffer),
            ("testFrameEncoderCanPrependHeaderToExtensionBuffer", testFrameEncoderCanPrependHeaderToExtensionBuffer),
            ("testFrameEncoderCanPrependMediumHeader", testFrameEncoderCanPrependMediumHeader),
            ("testFrameEncoderCanPrependLargeHeader", testFrameEncoderCanPrependLargeHeader),
            ("testFrameEncoderFailsToPrependHeaderWithInsufficientSpace", testFrameEncoderFailsToPrependHeaderWithInsufficientSpace),
            ("testFrameEncoderFailsToPrependMediumHeaderWithInsufficientSpace", testFrameEncoderFailsToPrependMediumHeaderWithInsufficientSpace),
            ("testFrameEncoderFailsToPrependLargeHeaderWithInsufficientSpace", testFrameEncoderFailsToPrependLargeHeaderWithInsufficientSpace)
        ]
    }
}
