//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Helpers

public typealias Triple = Helpers.Triple

extension Triple: @unchecked Sendable {}

extension Triple {

  public var linuxConventionDescription: String {
    "\(self.arch!.linuxConventionName)-\(self.vendor?.rawValue ?? "unknown")-\(self.os!)\(self.environment != nil ? "-\(self.environment!)" : "")"
  }

  public init(arch: Arch, vendor: Vendor?, os: OS, environment: Environment) {
    self.init("\(arch)-\(vendor?.rawValue ?? "unknown")-\(os)-\(environment)", normalizing: true)
  }

  public init(arch: Arch, vendor: Vendor?, os: OS) {
    self.init("\(arch)-\(vendor?.rawValue ?? "unknown")-\(os)", normalizing: true)
  }
}

extension Triple.Arch {
  /// Returns the value of `cpu` converted to a convention used by Swift on Linux, i.e. `arm64` becomes `aarch64`.
  var linuxConventionName: String {
    switch self {
    case .aarch64: "aarch64"
    case .x86_64: "x86_64"
    case .wasm32: "wasm32"
    default: fatalError("\(self) is not supported yet")
    }
  }

  /// Returns the value of `cpu` converted to a convention used by `LLVM_TARGETS_TO_BUILD` CMake setting.
  var llvmTargetConventionName: String {
    switch self {
    case .x86_64: "X86"
    case .aarch64: "AArch64"
    case .wasm32: "WebAssembly"
    default: fatalError("\(self) is not supported yet")
    }
  }
}
