import XCTest
import SystemPackage
import Shared
@testable import TestShared
@testable import PeripheryKit

#if os(macOS)
final class ObjcRetentionTest: FixtureSourceGraphTestCase {
    static override func setUp() {
        super.setUp()

        configuration.targets = ["ObjcRetentionFixtures"]

        build(driver: SPMProjectDriver.self)
    }

    // https://bugs.swift.org/browse/SR-13930
    func testRetainsOptionalProtocolMethodImplementedInSubclass() {
        guard performKnownFailures else { return }

        analyze(retainPublic: true) {
            assertReferenced(.class("FixtureClass125Base"))
            assertReferenced(.class("FixtureClass125")) {
                self.assertReferenced(.functionMethodInstance("fileManager(_:shouldRemoveItemAtPath:)"))
            }
        }
    }

    func testRetainsOptionalProtocolMethod() {
        analyze(retainPublic: true) {
            assertReferenced(.class("FixtureClass127")) {
                self.assertReferenced(.functionMethodInstance("someFunc()"))
            }
            assertReferenced(.protocol("FixtureProtocol127")) {
                self.assertReferenced(.functionMethodInstance("optionalFunc()"))
            }
        }
    }

    func testRetainsObjcAnnotatedClass() {
        analyze(retainObjcAccessible: true) {
            assertReferenced(.class("FixtureClass21"))
        }
    }

    func testRetainsImplicitlyObjcAccessibleClass() {
        analyze(retainObjcAccessible: true) {
            assertReferenced(.class("FixtureClass126"))
        }
    }

    func testRetainsObjcAnnotatedMembers() {
        analyze(retainObjcAccessible: true) {
            assertReferenced(.class("FixtureClass22")) {
                self.assertReferenced(.varInstance("someVar"))
                self.assertReferenced(.functionMethodInstance("someMethod()"))
                self.assertReferenced(.functionMethodInstance("somePrivateMethod()"))
            }
        }
    }

    func testDoesNotRetainObjcAnnotatedWithoutOption() {
        analyze {
            assertNotReferenced(.class("FixtureClass23"))
        }
    }

    func testDoesNotRetainMembersOfObjcAnnotatedClass() {
        analyze(retainObjcAccessible: true) {
            assertReferenced(.class("FixtureClass24")) {
                self.assertNotReferenced(.functionMethodInstance("someMethod()"))
                self.assertNotReferenced(.varInstance("someVar"))
            }
        }
    }

    func testObjcMembersAnnotationRetainsMembers() {
        analyze(retainObjcAccessible: true) {
            assertReferenced(.class("FixtureClass25")) {
                self.assertReferenced(.varInstance("someVar"))
                self.assertReferenced(.functionMethodInstance("someMethod()"))
                self.assertNotReferenced(.functionMethodInstance("somePrivateMethod()"))
            }
        }
    }
}
#endif
