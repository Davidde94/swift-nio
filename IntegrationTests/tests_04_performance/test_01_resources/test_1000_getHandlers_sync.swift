//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

private final class SimpleHandler: ChannelInboundHandler {
    typealias InboundIn = NIOAny
}

func run(identifier: String) {
    measure(identifier: identifier) {
        let iterations = 1000
        let channel = EmbeddedChannel()
        defer {
            _ = try! channel.finish()
        }
        try! channel.pipeline.syncOperations.addHandler(SimpleHandler())

        for _ in 0..<iterations {
            _ = try! channel.pipeline.syncOperations.handler(type: SimpleHandler.self)
        }
        return iterations
    }
}
