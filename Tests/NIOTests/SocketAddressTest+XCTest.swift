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
// SocketAddressTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension SocketAddressTest {
    @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
    static var allTests: [(String, (SocketAddressTest) -> () throws -> Void)] {
        [
            ("testDescriptionWorks", testDescriptionWorks),
            ("testDescriptionWorksWithoutIP", testDescriptionWorksWithoutIP),
            ("testDescriptionWorksWithIPOnly", testDescriptionWorksWithIPOnly),
            ("testDescriptionWorksWithByteBufferIPv4IP", testDescriptionWorksWithByteBufferIPv4IP),
            ("testDescriptionWorksWithByteBufferIPv6IP", testDescriptionWorksWithByteBufferIPv6IP),
            ("testRejectsWrongIPByteBufferLength", testRejectsWrongIPByteBufferLength),
            ("testIn6AddrDescriptionWorks", testIn6AddrDescriptionWorks),
            ("testIPAddressWorks", testIPAddressWorks),
            ("testCanCreateIPv4AddressFromString", testCanCreateIPv4AddressFromString),
            ("testCanCreateIPv6AddressFromString", testCanCreateIPv6AddressFromString),
            ("testRejectsNonIPStrings", testRejectsNonIPStrings),
            ("testWithMutableAddressCopiesFaithfully", testWithMutableAddressCopiesFaithfully),
            ("testWithMutableAddressAllowsMutationWithoutPersistence", testWithMutableAddressAllowsMutationWithoutPersistence),
            ("testConvertingStorage", testConvertingStorage),
            ("testComparingSockaddrs", testComparingSockaddrs),
            ("testEqualSocketAddresses", testEqualSocketAddresses),
            ("testUnequalAddressesOnPort", testUnequalAddressesOnPort),
            ("testUnequalOnAddress", testUnequalOnAddress),
            ("testHashEqualSocketAddresses", testHashEqualSocketAddresses),
            ("testHashUnequalAddressesOnPort", testHashUnequalAddressesOnPort),
            ("testHashUnequalOnAddress", testHashUnequalOnAddress),
            ("testUnequalAcrossFamilies", testUnequalAcrossFamilies),
            ("testUnixSocketAddressIgnoresTrailingJunk", testUnixSocketAddressIgnoresTrailingJunk),
            ("testPortAccessor", testPortAccessor),
            ("testCanMutateSockaddrStorage", testCanMutateSockaddrStorage),
            ("testPortIsMutable", testPortIsMutable)
        ]
    }
}
