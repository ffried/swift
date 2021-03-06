/// Test the generated private textual module interfaces and that the public
/// one doesn't leak SPI decls and info.

// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -emit-module %S/Inputs/spi_helper.swift -module-name SPIHelper -emit-module-path %t/SPIHelper.swiftmodule -swift-version 5 -enable-library-evolution -emit-module-interface-path %t/SPIHelper.swiftinterface -emit-private-module-interface-path %t/SPIHelper.private.swiftinterface

/// Make sure that the public swiftinterface of spi_helper doesn't leak SPI.
// RUN: %FileCheck -check-prefix=CHECK-HELPER %s < %t/SPIHelper.swiftinterface
// CHECK-HELPER-NOT: HelperSPI
// CHECK-HELPER-NOT: @_spi
// RUN: %target-swift-frontend -emit-module %t/SPIHelper.swiftinterface -emit-module-path %t/SPIHelper-from-public-swiftinterface.swiftmodule -swift-version 5 -module-name SPIHelper -enable-library-evolution

/// Test the textual interfaces generated from this test.
// RUN: %target-swift-frontend -typecheck %s -emit-module-interface-path %t/main.swiftinterface -emit-private-module-interface-path %t/main.private.swiftinterface -enable-library-evolution -swift-version 5 -I %t
// RUN: %FileCheck -check-prefix=CHECK-PUBLIC %s < %t/main.swiftinterface
// RUN: %FileCheck -check-prefix=CHECK-PRIVATE %s < %t/main.private.swiftinterface

/// Serialize and deserialize this module, then print.
// RUN: %target-swift-frontend -emit-module %s -emit-module-path %t/merged-partial.swiftmodule -swift-version 5 -I %t -module-name merged -enable-library-evolution
// RUN: %target-swift-frontend -merge-modules %t/merged-partial.swiftmodule -module-name merged -emit-module -emit-module-path %t/merged.swiftmodule -I %t -emit-module-interface-path %t/merged.swiftinterface -emit-private-module-interface-path %t/merged.private.swiftinterface -enable-library-evolution -swift-version 5 -I %t
// RUN: %FileCheck -check-prefix=CHECK-PUBLIC %s < %t/merged.swiftinterface
// RUN: %FileCheck -check-prefix=CHECK-PRIVATE %s < %t/merged.private.swiftinterface

@_spi(HelperSPI) @_spi(OtherSPI) @_spi(OtherSPI) import SPIHelper
// CHECK-PUBLIC: import SPIHelper
// CHECK-PRIVATE: @_spi(OtherSPI) @_spi(HelperSPI) import SPIHelper

public func foo() {}
// CHECK-PUBLIC: foo()
// CHECK-PRIVATE: foo()

@_spi(MySPI) @_spi(MyOtherSPI) public func localSPIFunc() {}
// CHECK-PRIVATE: @_spi(MySPI)
// CHECK-PRIVATE: localSPIFunc()
// CHECK-PUBLIC-NOT: localSPIFunc()

// SPI declarations
@_spi(MySPI) public class SPIClassLocal {
// CHECK-PRIVATE: @_spi(MySPI) public class SPIClassLocal
// CHECK-PUBLIC-NOT: class SPIClassLocal

  public init() {}
}

@_spi(MySPI) public extension SPIClassLocal {
// CHECK-PRIVATE: @_spi(MySPI) extension SPIClassLocal
// CHECK-PUBLIC-NOT: extension SPIClassLocal

  @_spi(MySPI) func extensionMethod() {}
  // CHECK-PRIVATE: @_spi(MySPI) public func extensionMethod
  // CHECK-PUBLIC-NOT: func extensionMethod

  internal func internalExtensionMethod() {}
  // CHECK-PRIVATE-NOT: internalExtensionMethod
  // CHECK-PUBLIC-NOT: internalExtensionMethod

  func inheritedSPIExtensionMethod() {}
  // CHECK-PRIVATE: inheritedSPIExtensionMethod
  // CHECK-PUBLIC-NOT: inheritedSPIExtensionMethod
}

public extension SPIClassLocal {
  internal func internalExtensionMethode1() {}
  // CHECK-PRIVATE-NOT: internalExtensionMethod1
  // CHECK-PUBLIC-NOT: internalExtensionMethod1
}

class InternalClassLocal {}
// CHECK-PRIVATE-NOT: InternalClassLocal
// CHECK-PUBLIC-NOT: InternalClassLocal

private class PrivateClassLocal {}
// CHECK-PRIVATE-NOT: PrivateClassLocal
// CHECK-PUBLIC-NOT: PrivateClassLocal

@_spi(LocalSPI) public func useOfSPITypeOk(_ p: SPIClassLocal) -> SPIClassLocal {
  fatalError()
}
// CHECK-PRIVATE: @_spi(LocalSPI) public func useOfSPITypeOk
// CHECK-PUBLIC-NOT: useOfSPITypeOk

@_spi(LocalSPI) extension SPIClass {
  // CHECK-PRIVATE: @_spi(LocalSPI) extension SPIClass
  // CHECK-PUBLIC-NOT: SPIClass

  @_spi(LocalSPI) public func extensionSPIMethod() {}
  // CHECK-PRIVATE: @_spi(LocalSPI) public func extensionSPIMethod()
  // CHECK-PUBLIC-NOT: extensionSPIMethod
}

// Test the dummy conformance printed to replace private types used in
// conditional conformances. rdar://problem/63352700

// Conditional conformances using SPI types should appear in full in the
// private swiftinterface.
public struct PublicType<T> {}
@_spi(LocalSPI) public protocol SPIProto {}
private protocol PrivateConstraint {}
@_spi(LocalSPI) public protocol SPIProto2 {}

@_spi(LocalSPI)
extension PublicType: SPIProto2 where T: SPIProto2 {}
// CHECK-PRIVATE: extension PublicType : {{.*}}.SPIProto2 where T : {{.*}}.SPIProto2
// CHECK-PUBLIC-NOT: _ConstraintThatIsNotPartOfTheAPIOfThisLibrary

// The dummy conformance should be only in the private swiftinterface for
// SPI extensions.
@_spi(LocalSPI)
extension PublicType: SPIProto where T: PrivateConstraint {}
// CHECK-PRIVATE: extension {{.*}}.PublicType : {{.*}}.SPIProto where T : _ConstraintThatIsNotPartOfTheAPIOfThisLibrary
// CHECK-PUBLIC-NOT: _ConstraintThatIsNotPartOfTheAPIOfThisLibrary
