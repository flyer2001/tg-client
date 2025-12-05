# SwiftPM Hang Testing Results

**Issue:** https://github.com/swiftlang/swift-package-manager/issues/9441
**Date:** 2025-12-05
**System:** Linux 6.8.0-60-generic, Ubuntu 24.04
**Disk Space:** 6.3GB available (74% used)

**Maintainer Request:**
1. Test in home directory instead of /tmp
2. Test on Swift 6.0 and 5.10

## Summary

| Swift Version | Location | Clean Build | Incremental Build |
|---------------|----------|-------------|-------------------|
| **6.2.1** | ~/swiftpm-test-621 | ✅ SUCCESS | ❌ **HANGS at "Planning build"** (exit 124) |
| 6.2 | ~/swiftpm-test | ✅ SUCCESS (9.25s) | ❌ **HANGS at "Planning build"** |
| **6.1** | ~/swiftpm-test-61 | ✅ SUCCESS | ❌ **HANGS at "Planning build"** (exit 124) |
| 6.0 | ~/swiftpm-test-60 | ✅ SUCCESS (7.98s) | ✅ **SUCCESS** (exit 0) |
| 5.10 | ~/swiftpm-test-510 | ✅ SUCCESS (7.68s) | ✅ **SUCCESS** (exit 0) |

### Key Findings

1. **Regression between Swift 6.0 and 6.1**: All versions 6.1, 6.2, and 6.2.1 hang, but 6.0 works fine
2. **Not fixed in 6.2.1**: The latest patch release (6.2.1) still has the issue
3. **Not environment-specific**: Issue reproduces in both /tmp and home directory
4. **Hang location**: Exactly at "Planning build" stage during incremental builds
5. **Swift 6.0 and 5.10 work fine**: No hangs on incremental builds

### Recommendation

This appears to be a regression introduced **between Swift 6.0 and 6.1** and remains unfixed. Consider:
- **High priority**: Bisecting between 6.0 and 6.1 to find the problematic commit
- Investigating changes to build plan generation in SwiftPM 6.1
- Reviewing SwiftPM commits between swift-6.0-RELEASE and swift-6.1-RELEASE tags
- Consider backporting the fix to 6.2.x patch releases

---

## Test 1: Swift 6.2 in ~/swiftpm-test

**Swift Version:**
```
Swift version 6.2 (swift-6.2-RELEASE)
Target: x86_64-unknown-linux-gnu
```

**Project Location:** ~/swiftpm-test

### Initial Build (Clean State)

**Command:** `swift build --verbose`
**Result:** ✅ SUCCESS
**Time:** ~9.25s

**Last line of verbose output:**
```
Build complete! (9.25s)
```

### Incremental Build (After Adding Comment)

**Modification:** `echo '// Test comment for incremental build' >> Sources/swiftpm-test/swiftpm_test.swift`
**Command:** `swift build --verbose` (with 30s timeout)
**Result:** ❌ HUNG at "Planning build"
**Exit Code:** 124 (timeout)

**Verbose output (last lines before hang):**
```
Planning build
[HANGS INDEFINITELY]
```

**Conclusion:**
- Issue reproduces in home directory (not specific to /tmp)
- **Hangs exactly at "Planning build" stage**
- Clean builds work fine, only incremental builds hang

---
## Test 2: Swift 6.0 in ~/swiftpm-test
Swift version 6.0 (swift-6.0-RELEASE)
Target: x86_64-unknown-linux-gnu

### Clean Build

warning: 'swiftpm-test-60': /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-60/Package.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -vfsoverlay /tmp/TemporaryDirectory.hpapSu/vfs.yaml -swift-version 6 -package-description-version 6.0.0 -empty-abi-descriptor -resource-dir /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift -module-name main -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -o /tmp/TemporaryDirectory.ZZ197g/Package-1.o
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-autolink-extract /tmp/TemporaryDirectory.ZZ197g/Package-1.o -o /tmp/TemporaryDirectory.ZZ197g/main-1.autolink
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/clang -fuse-ld=gold -pie -Xlinker -rpath -Xlinker /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.ZZ197g/Package-1.o @/tmp/TemporaryDirectory.ZZ197g/main-1.autolink -L /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux -lswiftCore --target=x86_64-unknown-linux-gnu -v -L /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lPackageDescription -Xlinker -rpath -Xlinker /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -o /tmp/TemporaryDirectory.LefQNw/swiftpm-test-60-manifest
Swift version 6.0 (swift-6.0-RELEASE)
Target: x86_64-unknown-linux-gnu
clang version 17.0.0 (https://github.com/swiftlang/llvm-project.git 73500bf55acff5fa97b56dcdeb013f288efd084f)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin
Found candidate GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Selected GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Candidate multilib: .;@m64
Selected multilib: .;@m64
 "/usr/bin/ld.gold" -pie --hash-style=gnu --eh-frame-hdr -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o /tmp/TemporaryDirectory.LefQNw/swiftpm-test-60-manifest /lib/x86_64-linux-gnu/Scrt1.o /lib/x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/13/crtbeginS.o -L/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux -L/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -L/usr/lib/gcc/x86_64-linux-gnu/13 -L/usr/lib/gcc/x86_64-linux-gnu/13/../../../../lib64 -L/lib/x86_64-linux-gnu -L/lib/../lib64 -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib64 -L/lib -L/usr/lib -rpath /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.ZZ197g/Package-1.o -lswiftSwiftOnoneSupport -lswiftCore -lswift_Concurrency -lswift_StringProcessing -lswift_RegexParser -lswiftCore -lPackageDescription -rpath /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed /usr/lib/gcc/x86_64-linux-gnu/13/crtendS.o /lib/x86_64-linux-gnu/crtn.o
Building for debugging...
Write auxiliary file /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/sources
Write auxiliary file /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swift-version-297A43C580B13274.txt
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swiftc -module-name swiftpm_test_60 -emit-dependencies -emit-module -emit-module-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftmodule -output-file-map /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/output-file-map.json -parse-as-library -incremental -c @/root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/sources -I /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules -target x86_64-unknown-linux-gnu -v -enable-batch-mode -index-store-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/index/store -Onone -enable-testing -j1 -DSWIFT_PACKAGE -DDEBUG -module-cache-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -parseable-output -parse-as-library -swift-version 6 -g -Xcc -fPIC -Xcc -g -package-name swiftpm_test_60 -Xcc -fno-omit-frame-pointer
Swift version 6.0 (swift-6.0-RELEASE)
Target: x86_64-unknown-linux-gnu
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -emit-module -experimental-skip-non-inlinable-function-bodies-without-types /root/swiftpm-test-60/Sources/swiftpm-test-60/swiftpm_test_60.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -empty-abi-descriptor -resource-dir /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift -enable-anonymous-context-mangled-names -file-compilation-dir /root/swiftpm-test-60 -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_60 -package-name swiftpm_test_60 -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -emit-module-doc-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftdoc -emit-module-source-info-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftsourceinfo -emit-dependencies-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/swiftpm_test_60.emit-module.d -parse-as-library -o /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftmodule
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-60/Sources/swiftpm-test-60/swiftpm_test_60.swift -emit-dependencies-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/swiftpm_test_60.d -emit-reference-dependencies-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/swiftpm_test_60.swiftdeps -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -empty-abi-descriptor -resource-dir /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift -enable-anonymous-context-mangled-names -file-compilation-dir /root/swiftpm-test-60 -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_60 -package-name swiftpm_test_60 -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -parse-as-library -o /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/swiftpm_test_60.swift.o -index-store-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/index/store -index-system-modules
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-frontend -modulewrap /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftmodule -target x86_64-unknown-linux-gnu -o /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.o
Build complete! (7.98s)

### Incremental Build (timeout 30s)

Incremental build exit code: 0
warning: 'swiftpm-test-60': /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-60/Package.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -vfsoverlay /tmp/TemporaryDirectory.qKISod/vfs.yaml -swift-version 6 -package-description-version 6.0.0 -empty-abi-descriptor -resource-dir /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift -module-name main -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -o /tmp/TemporaryDirectory.xWF3Us/Package-1.o
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-autolink-extract /tmp/TemporaryDirectory.xWF3Us/Package-1.o -o /tmp/TemporaryDirectory.xWF3Us/main-1.autolink
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/clang -fuse-ld=gold -pie -Xlinker -rpath -Xlinker /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.xWF3Us/Package-1.o @/tmp/TemporaryDirectory.xWF3Us/main-1.autolink -L /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux -lswiftCore --target=x86_64-unknown-linux-gnu -v -L /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lPackageDescription -Xlinker -rpath -Xlinker /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -o /tmp/TemporaryDirectory.mlYvS3/swiftpm-test-60-manifest
Swift version 6.0 (swift-6.0-RELEASE)
Target: x86_64-unknown-linux-gnu
clang version 17.0.0 (https://github.com/swiftlang/llvm-project.git 73500bf55acff5fa97b56dcdeb013f288efd084f)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin
Found candidate GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Selected GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Candidate multilib: .;@m64
Selected multilib: .;@m64
 "/usr/bin/ld.gold" -pie --hash-style=gnu --eh-frame-hdr -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o /tmp/TemporaryDirectory.mlYvS3/swiftpm-test-60-manifest /lib/x86_64-linux-gnu/Scrt1.o /lib/x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/13/crtbeginS.o -L/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux -L/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -L/usr/lib/gcc/x86_64-linux-gnu/13 -L/usr/lib/gcc/x86_64-linux-gnu/13/../../../../lib64 -L/lib/x86_64-linux-gnu -L/lib/../lib64 -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib64 -L/lib -L/usr/lib -rpath /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.xWF3Us/Package-1.o -lswiftSwiftOnoneSupport -lswiftCore -lswift_Concurrency -lswift_StringProcessing -lswift_RegexParser -lswiftCore -lPackageDescription -rpath /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed /usr/lib/gcc/x86_64-linux-gnu/13/crtendS.o /lib/x86_64-linux-gnu/crtn.o
Planning build
Building for debugging...
Write auxiliary file /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/sources
Write auxiliary file /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swift-version-297A43C580B13274.txt
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swiftc -module-name swiftpm_test_60 -emit-dependencies -emit-module -emit-module-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftmodule -output-file-map /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/output-file-map.json -parse-as-library -incremental -c @/root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/sources -I /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules -target x86_64-unknown-linux-gnu -v -enable-batch-mode -index-store-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/index/store -Onone -enable-testing -j1 -DSWIFT_PACKAGE -DDEBUG -module-cache-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -parseable-output -parse-as-library -swift-version 6 -g -Xcc -fPIC -Xcc -g -package-name swiftpm_test_60 -Xcc -fno-omit-frame-pointer
Swift version 6.0 (swift-6.0-RELEASE)
Target: x86_64-unknown-linux-gnu
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -emit-module -experimental-skip-non-inlinable-function-bodies-without-types /root/swiftpm-test-60/Sources/swiftpm-test-60/swiftpm_test_60.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -empty-abi-descriptor -resource-dir /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift -enable-anonymous-context-mangled-names -file-compilation-dir /root/swiftpm-test-60 -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_60 -package-name swiftpm_test_60 -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -emit-module-doc-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftdoc -emit-module-source-info-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftsourceinfo -emit-dependencies-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/swiftpm_test_60.emit-module.d -parse-as-library -o /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftmodule
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-60/Sources/swiftpm-test-60/swiftpm_test_60.swift -emit-dependencies-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/swiftpm_test_60.d -emit-reference-dependencies-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/swiftpm_test_60.swiftdeps -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -empty-abi-descriptor -resource-dir /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift -enable-anonymous-context-mangled-names -file-compilation-dir /root/swiftpm-test-60 -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_60 -package-name swiftpm_test_60 -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.0-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -parse-as-library -o /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_60.build/swiftpm_test_60.swift.o -index-store-path /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/index/store -index-system-modules
/tmp/swift-6.0-RELEASE-ubuntu24.04/usr/bin/swift-frontend -modulewrap /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.swiftmodule -target x86_64-unknown-linux-gnu -o /root/swiftpm-test-60/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_60.o
Build complete! (1.86s)

---
## Test 3: Swift 5.10 in ~/swiftpm-test-510

Swift version 5.10 (swift-5.10-RELEASE)
Target: x86_64-unknown-linux-gnu

### Clean Build

Exit code: 0
warning: 'swiftpm-test-510': /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-510/Package.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -vfsoverlay /tmp/TemporaryDirectory.eY0ve1/vfs.yaml -swift-version 5 -package-description-version 5.10.0 -new-driver-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-driver -disable-implicit-concurrency-module-import -disable-implicit-string-processing-module-import -empty-abi-descriptor -resource-dir /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift -module-name main -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/local/lib/swift/host/plugins -o /tmp/TemporaryDirectory.3gGmZ1/Package-1.o
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-autolink-extract /tmp/TemporaryDirectory.3gGmZ1/Package-1.o -o /tmp/TemporaryDirectory.3gGmZ1/main-1.autolink
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/clang -fuse-ld=gold -pie -Xlinker -rpath -Xlinker /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.3gGmZ1/Package-1.o @/tmp/TemporaryDirectory.3gGmZ1/main-1.autolink -L /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux -lswiftCore --target=x86_64-unknown-linux-gnu -v -L /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -lPackageDescription -Xlinker -rpath -Xlinker /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -o /tmp/TemporaryDirectory.UUDPDh/swiftpm-test-510-manifest
Swift version 5.10 (swift-5.10-RELEASE)
Target: x86_64-unknown-linux-gnu
clang version 15.0.0 (https://github.com/apple/llvm-project.git 5dc9d563e5a6cd2cdd44117697dead98955ccddf)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin
Found candidate GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Selected GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Candidate multilib: .;@m64
Selected multilib: .;@m64
 "/usr/bin/ld.gold" -pie --hash-style=gnu --eh-frame-hdr -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o /tmp/TemporaryDirectory.UUDPDh/swiftpm-test-510-manifest /lib/x86_64-linux-gnu/Scrt1.o /lib/x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/13/crtbeginS.o -L/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux -L/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -L/usr/lib/gcc/x86_64-linux-gnu/13 -L/usr/lib/gcc/x86_64-linux-gnu/13/../../../../lib64 -L/lib/x86_64-linux-gnu -L/lib/../lib64 -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib64 -L/lib -L/usr/lib -rpath /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.3gGmZ1/Package-1.o -lswiftSwiftOnoneSupport -lswiftCore -lswiftCore -lPackageDescription -rpath /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed /usr/lib/gcc/x86_64-linux-gnu/13/crtendS.o /lib/x86_64-linux-gnu/crtn.o
Building for debugging...
Write auxiliary file /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/sources
Write auxiliary file /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swift-version--5E051BF7CF22635D.txt
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swiftc -module-name swiftpm_test_510 -emit-dependencies -emit-module -emit-module-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftmodule -output-file-map /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/output-file-map.json -parse-as-library -incremental -c @/root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/sources -I /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug -target x86_64-unknown-linux-gnu -swift-version 5 -v -enable-batch-mode -index-store-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/index/store -Onone -enable-testing -j1 -DSWIFT_PACKAGE -DDEBUG -module-cache-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -parseable-output -parse-as-library -g -Xcc -fPIC -Xcc -g -package-name swiftpm_test_510 -Xcc -fno-omit-frame-pointer
Swift version 5.10 (swift-5.10-RELEASE)
Target: x86_64-unknown-linux-gnu
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-frontend -frontend -emit-module -experimental-skip-non-inlinable-function-bodies-without-types /root/swiftpm-test-510/Sources/swiftpm-test-510/swiftpm_test_510.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug -enable-testing -g -module-cache-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 5 -Onone -D SWIFT_PACKAGE -D DEBUG -new-driver-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-driver -empty-abi-descriptor -resource-dir /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift -enable-anonymous-context-mangled-names -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_510 -package-name swiftpm_test_510 -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/local/lib/swift/host/plugins -emit-module-doc-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftdoc -emit-module-source-info-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftsourceinfo -emit-dependencies-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/swiftpm_test_510.emit-module.d -parse-as-library -o /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftmodule
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-510/Sources/swiftpm-test-510/swiftpm_test_510.swift -emit-dependencies-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/swiftpm_test_510.d -emit-reference-dependencies-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/swiftpm_test_510.swiftdeps -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug -enable-testing -g -module-cache-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 5 -Onone -D SWIFT_PACKAGE -D DEBUG -new-driver-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-driver -empty-abi-descriptor -resource-dir /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift -enable-anonymous-context-mangled-names -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_510 -package-name swiftpm_test_510 -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/local/lib/swift/host/plugins -parse-as-library -o /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/swiftpm_test_510.swift.o -index-store-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/index/store -index-system-modules
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-frontend -modulewrap /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftmodule -target x86_64-unknown-linux-gnu -o /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.o
Build complete! (7.68s)

### Incremental Build (timeout 30s)

Exit code: 0
Planning build
warning: 'swiftpm-test-510': /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-510/Package.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -vfsoverlay /tmp/TemporaryDirectory.lshEfX/vfs.yaml -swift-version 5 -package-description-version 5.10.0 -new-driver-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-driver -disable-implicit-concurrency-module-import -disable-implicit-string-processing-module-import -empty-abi-descriptor -resource-dir /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift -module-name main -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/local/lib/swift/host/plugins -o /tmp/TemporaryDirectory.DJSb7S/Package-1.o
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-autolink-extract /tmp/TemporaryDirectory.DJSb7S/Package-1.o -o /tmp/TemporaryDirectory.DJSb7S/main-1.autolink
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/clang -fuse-ld=gold -pie -Xlinker -rpath -Xlinker /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.DJSb7S/Package-1.o @/tmp/TemporaryDirectory.DJSb7S/main-1.autolink -L /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux -lswiftCore --target=x86_64-unknown-linux-gnu -v -L /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -lPackageDescription -Xlinker -rpath -Xlinker /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -o /tmp/TemporaryDirectory.QZcas6/swiftpm-test-510-manifest
Swift version 5.10 (swift-5.10-RELEASE)
Target: x86_64-unknown-linux-gnu
clang version 15.0.0 (https://github.com/apple/llvm-project.git 5dc9d563e5a6cd2cdd44117697dead98955ccddf)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin
Found candidate GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Selected GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Candidate multilib: .;@m64
Selected multilib: .;@m64
 "/usr/bin/ld.gold" -pie --hash-style=gnu --eh-frame-hdr -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o /tmp/TemporaryDirectory.QZcas6/swiftpm-test-510-manifest /lib/x86_64-linux-gnu/Scrt1.o /lib/x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/13/crtbeginS.o -L/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux -L/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -L/usr/lib/gcc/x86_64-linux-gnu/13 -L/usr/lib/gcc/x86_64-linux-gnu/13/../../../../lib64 -L/lib/x86_64-linux-gnu -L/lib/../lib64 -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib64 -L/lib -L/usr/lib -rpath /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.DJSb7S/Package-1.o -lswiftSwiftOnoneSupport -lswiftCore -lswiftCore -lPackageDescription -rpath /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/pm/ManifestAPI -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed /usr/lib/gcc/x86_64-linux-gnu/13/crtendS.o /lib/x86_64-linux-gnu/crtn.o
Building for debugging...
Write auxiliary file /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/sources
Write auxiliary file /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swift-version--5E051BF7CF22635D.txt
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swiftc -module-name swiftpm_test_510 -emit-dependencies -emit-module -emit-module-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftmodule -output-file-map /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/output-file-map.json -parse-as-library -incremental -c @/root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/sources -I /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug -target x86_64-unknown-linux-gnu -swift-version 5 -v -enable-batch-mode -index-store-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/index/store -Onone -enable-testing -j1 -DSWIFT_PACKAGE -DDEBUG -module-cache-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -parseable-output -parse-as-library -g -Xcc -fPIC -Xcc -g -package-name swiftpm_test_510 -Xcc -fno-omit-frame-pointer
Swift version 5.10 (swift-5.10-RELEASE)
Target: x86_64-unknown-linux-gnu
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-frontend -frontend -emit-module -experimental-skip-non-inlinable-function-bodies-without-types /root/swiftpm-test-510/Sources/swiftpm-test-510/swiftpm_test_510.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug -enable-testing -g -module-cache-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 5 -Onone -D SWIFT_PACKAGE -D DEBUG -new-driver-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-driver -empty-abi-descriptor -resource-dir /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift -enable-anonymous-context-mangled-names -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_510 -package-name swiftpm_test_510 -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/local/lib/swift/host/plugins -emit-module-doc-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftdoc -emit-module-source-info-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftsourceinfo -emit-dependencies-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/swiftpm_test_510.emit-module.d -parse-as-library -o /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftmodule
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-510/Sources/swiftpm-test-510/swiftpm_test_510.swift -emit-dependencies-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/swiftpm_test_510.d -emit-reference-dependencies-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/swiftpm_test_510.swiftdeps -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug -enable-testing -g -module-cache-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 5 -Onone -D SWIFT_PACKAGE -D DEBUG -new-driver-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-driver -empty-abi-descriptor -resource-dir /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift -enable-anonymous-context-mangled-names -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_510 -package-name swiftpm_test_510 -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-5.10-RELEASE-ubuntu22.04/usr/local/lib/swift/host/plugins -parse-as-library -o /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.build/swiftpm_test_510.swift.o -index-store-path /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/index/store -index-system-modules
/tmp/swift-5.10-RELEASE-ubuntu22.04/usr/bin/swift-frontend -modulewrap /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.swiftmodule -target x86_64-unknown-linux-gnu -o /root/swiftpm-test-510/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_510.o
Build complete! (3.37s)

---
## Test 4: Swift 6.1 in ~/swiftpm-test-61

Swift version 6.1 (swift-6.1-RELEASE)
Target: x86_64-unknown-linux-gnu

### Clean Build

Exit code: 0
warning: 'swiftpm-test-61': /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-61/Package.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -vfsoverlay /tmp/TemporaryDirectory.QdXhsZ/vfs.yaml -swift-version 6 -package-description-version 6.1.0 -empty-abi-descriptor -resource-dir /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift -module-name main -in-process-plugin-server-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/host/libSwiftInProcPluginServer.so -plugin-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -o /tmp/TemporaryDirectory.RKm6jE/Package-1.o
/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/swift-autolink-extract /tmp/TemporaryDirectory.RKm6jE/Package-1.o -o /tmp/TemporaryDirectory.RKm6jE/main-1.autolink
/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/clang -pie -Xlinker --build-id -Xlinker -rpath -Xlinker /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.RKm6jE/Package-1.o @/tmp/TemporaryDirectory.RKm6jE/main-1.autolink -L /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux -lswiftCore --target=x86_64-unknown-linux-gnu -v -L /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lPackageDescription -Xlinker -rpath -Xlinker /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -o /tmp/TemporaryDirectory.0PFY6G/swiftpm-test-61-manifest
Swift version 6.1 (swift-6.1-RELEASE)
Target: x86_64-unknown-linux-gnu
clang version 17.0.0 (https://github.com/swiftlang/llvm-project.git 901f89886dcd5d1eaf07c8504d58c90f37b0cfdf)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin
Found candidate GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Selected GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Candidate multilib: .;@m64
Selected multilib: .;@m64
 "/usr/bin/ld.gold" -z relro --hash-style=gnu --eh-frame-hdr -m elf_x86_64 -pie -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o /tmp/TemporaryDirectory.0PFY6G/swiftpm-test-61-manifest /lib/x86_64-linux-gnu/Scrt1.o /lib/x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/13/crtbeginS.o -L/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux -L/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -L/usr/lib/gcc/x86_64-linux-gnu/13 -L/usr/lib/gcc/x86_64-linux-gnu/13/../../../../lib64 -L/lib/x86_64-linux-gnu -L/lib/../lib64 -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib64 -L/lib -L/usr/lib --build-id -rpath /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.RKm6jE/Package-1.o -lswiftSwiftOnoneSupport -lswiftCore -lswift_Concurrency -lswift_StringProcessing -lswift_RegexParser -lswiftCore -lPackageDescription -rpath /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed /usr/lib/gcc/x86_64-linux-gnu/13/crtendS.o /lib/x86_64-linux-gnu/crtn.o
Building for debugging...
Write auxiliary file /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_61.build/sources
Write auxiliary file /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/swift-version--126EA8FAA5F9AA8B.txt
/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/swiftc -module-name swiftpm_test_61 -emit-dependencies -emit-module -emit-module-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_61.swiftmodule -output-file-map /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_61.build/output-file-map.json -parse-as-library -incremental -c @/root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_61.build/sources -I /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules -target x86_64-unknown-linux-gnu -v -enable-batch-mode -index-store-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/index/store -Onone -enable-testing -j1 -DSWIFT_PACKAGE -DDEBUG -module-cache-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -parseable-output -parse-as-library -swift-version 6 -g -Xcc -fPIC -Xcc -g -package-name swiftpm_test_61 -Xcc -fno-omit-frame-pointer
Swift version 6.1 (swift-6.1-RELEASE)
Target: x86_64-unknown-linux-gnu
/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -emit-module -experimental-skip-non-inlinable-function-bodies-without-types /root/swiftpm-test-61/Sources/swiftpm-test-61/swiftpm_test_61.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -empty-abi-descriptor -resource-dir /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift -enable-anonymous-context-mangled-names -file-compilation-dir /root/swiftpm-test-61 -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_61 -package-name swiftpm_test_61 -in-process-plugin-server-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/host/libSwiftInProcPluginServer.so -plugin-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -emit-module-doc-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_61.swiftdoc -emit-module-source-info-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_61.swiftsourceinfo -emit-dependencies-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_61.build/swiftpm_test_61.emit-module.d -parse-as-library -o /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_61.swiftmodule
/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-61/Sources/swiftpm-test-61/swiftpm_test_61.swift -emit-dependencies-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_61.build/swiftpm_test_61.d -emit-reference-dependencies-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_61.build/swiftpm_test_61.swiftdeps -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -empty-abi-descriptor -resource-dir /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift -enable-anonymous-context-mangled-names -file-compilation-dir /root/swiftpm-test-61 -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name swiftpm_test_61 -package-name swiftpm_test_61 -in-process-plugin-server-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/host/libSwiftInProcPluginServer.so -plugin-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -parse-as-library -o /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_61.build/swiftpm_test_61.swift.o -index-store-path /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/index/store -index-system-modules
/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -modulewrap /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_61.swiftmodule -target x86_64-unknown-linux-gnu -o /root/swiftpm-test-61/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_61.o
Build complete! (8.19s)

### Incremental Build (timeout 30s)

Exit code: 124
warning: 'swiftpm-test-61': /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-61/Package.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -vfsoverlay /tmp/TemporaryDirectory.VtG90p/vfs.yaml -swift-version 6 -package-description-version 6.1.0 -empty-abi-descriptor -resource-dir /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift -module-name main -in-process-plugin-server-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/host/libSwiftInProcPluginServer.so -plugin-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -o /tmp/TemporaryDirectory.JLiFpI/Package-1.o
/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/swift-autolink-extract /tmp/TemporaryDirectory.JLiFpI/Package-1.o -o /tmp/TemporaryDirectory.JLiFpI/main-1.autolink
/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin/clang -pie -Xlinker --build-id -Xlinker -rpath -Xlinker /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.JLiFpI/Package-1.o @/tmp/TemporaryDirectory.JLiFpI/main-1.autolink -L /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux -lswiftCore --target=x86_64-unknown-linux-gnu -v -L /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lPackageDescription -Xlinker -rpath -Xlinker /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -o /tmp/TemporaryDirectory.0pJzX8/swiftpm-test-61-manifest
Swift version 6.1 (swift-6.1-RELEASE)
Target: x86_64-unknown-linux-gnu
clang version 17.0.0 (https://github.com/swiftlang/llvm-project.git 901f89886dcd5d1eaf07c8504d58c90f37b0cfdf)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/bin
Found candidate GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Selected GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Candidate multilib: .;@m64
Selected multilib: .;@m64
 "/usr/bin/ld.gold" -z relro --hash-style=gnu --eh-frame-hdr -m elf_x86_64 -pie -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o /tmp/TemporaryDirectory.0pJzX8/swiftpm-test-61-manifest /lib/x86_64-linux-gnu/Scrt1.o /lib/x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/13/crtbeginS.o -L/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux -L/tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -L/usr/lib/gcc/x86_64-linux-gnu/13 -L/usr/lib/gcc/x86_64-linux-gnu/13/../../../../lib64 -L/lib/x86_64-linux-gnu -L/lib/../lib64 -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib64 -L/lib -L/usr/lib --build-id -rpath /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.JLiFpI/Package-1.o -lswiftSwiftOnoneSupport -lswiftCore -lswift_Concurrency -lswift_StringProcessing -lswift_RegexParser -lswiftCore -lPackageDescription -rpath /tmp/swift-6.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed /usr/lib/gcc/x86_64-linux-gnu/13/crtendS.o /lib/x86_64-linux-gnu/crtn.o
Planning build

---
## Test 5: Swift 6.2.1 in ~/swiftpm-test-621

Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu

### Clean Build

Exit code: 0
warning: 'swiftpm-test-621': /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-621/Package.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -vfsoverlay /tmp/TemporaryDirectory.4573JN/vfs.yaml -no-color-diagnostics -Xcc -fno-color-diagnostics -swift-version 6 -package-description-version 6.2.0 -empty-abi-descriptor -no-auto-bridging-header-chaining -module-name main -in-process-plugin-server-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/host/libSwiftInProcPluginServer.so -plugin-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -o /tmp/TemporaryDirectory.IHFNdD/Package-1.o
/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/swift-autolink-extract /tmp/TemporaryDirectory.IHFNdD/Package-1.o -o /tmp/TemporaryDirectory.IHFNdD/main-1.autolink
/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/clang -pie -Xlinker --build-id -Xlinker -rpath -Xlinker /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.IHFNdD/Package-1.o @/tmp/TemporaryDirectory.IHFNdD/main-1.autolink -L /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux -lswiftCore --target=x86_64-unknown-linux-gnu -v -L /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lPackageDescription -Xlinker -rpath -Xlinker /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -o /tmp/TemporaryDirectory.miasGs/swiftpm-test-621-manifest
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
clang version 17.0.0 (https://github.com/swiftlang/llvm-project.git 10999b6d034fe318f3d56c83bddb6572593a8bb0)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin
Found candidate GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Selected GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Candidate multilib: .;@m64
Selected multilib: .;@m64
 "/usr/bin/ld.gold" -z relro --hash-style=gnu --eh-frame-hdr -m elf_x86_64 -pie -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o /tmp/TemporaryDirectory.miasGs/swiftpm-test-621-manifest /lib/x86_64-linux-gnu/Scrt1.o /lib/x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/13/crtbeginS.o -L/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux -L/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -L/usr/lib/gcc/x86_64-linux-gnu/13 -L/usr/lib/gcc/x86_64-linux-gnu/13/../../../../lib64 -L/lib/x86_64-linux-gnu -L/lib/../lib64 -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib64 -L/lib -L/usr/lib --build-id -rpath /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.IHFNdD/Package-1.o -lswiftSwiftOnoneSupport -lswiftCore -lswift_Concurrency -lswift_StringProcessing -lswift_RegexParser -lswiftCore -lPackageDescription -rpath /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed /usr/lib/gcc/x86_64-linux-gnu/13/crtendS.o /lib/x86_64-linux-gnu/crtn.o
Building for debugging...
Write auxiliary file /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/sources
Write auxiliary file /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swift-version--5F6E1C08211A5629.txt
/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/swiftc -module-name swiftpm_test_621 -emit-dependencies -emit-module -emit-module-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_621.swiftmodule -output-file-map /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/output-file-map.json -parse-as-library -incremental -c @/root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/sources -I /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules -target x86_64-unknown-linux-gnu -v -incremental -enable-batch-mode -serialize-diagnostics -index-store-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/index/store -Onone -enable-testing -j1 -DSWIFT_PACKAGE -DDEBUG -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -module-cache-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -parseable-output -parse-as-library -emit-objc-header -emit-objc-header-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/include/swiftpm-test-621-Swift.h -swift-version 6 -g -Xcc -fPIC -Xcc -g -package-name swiftpm_test_621 -Xcc -fno-omit-frame-pointer
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -emit-module -experimental-skip-non-inlinable-function-bodies-without-types /root/swiftpm-test-621/Sources/swiftpm-test-621/swiftpm_test_621.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules -no-color-diagnostics -Xcc -fno-color-diagnostics -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -D SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -empty-abi-descriptor -enable-anonymous-context-mangled-names -file-compilation-dir /root/swiftpm-test-621 -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -no-auto-bridging-header-chaining -module-name swiftpm_test_621 -package-name swiftpm_test_621 -in-process-plugin-server-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/host/libSwiftInProcPluginServer.so -plugin-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -emit-module-doc-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_621.swiftdoc -emit-module-source-info-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_621.swiftsourceinfo -emit-objc-header-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/include/swiftpm-test-621-Swift.h -serialize-diagnostics-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/swiftpm_test_621.emit-module.dia -emit-dependencies-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/swiftpm_test_621.emit-module.d -parse-as-library -o /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_621.swiftmodule
/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-621/Sources/swiftpm-test-621/swiftpm_test_621.swift -emit-dependencies-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/swiftpm_test_621.d -emit-reference-dependencies-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/swiftpm_test_621.swiftdeps -serialize-diagnostics-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/swiftpm_test_621.dia -target x86_64-unknown-linux-gnu -disable-objc-interop -I /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules -no-color-diagnostics -Xcc -fno-color-diagnostics -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -D SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -empty-abi-descriptor -enable-anonymous-context-mangled-names -file-compilation-dir /root/swiftpm-test-621 -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -no-auto-bridging-header-chaining -module-name swiftpm_test_621 -package-name swiftpm_test_621 -in-process-plugin-server-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/host/libSwiftInProcPluginServer.so -plugin-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -parse-as-library -o /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/swiftpm_test_621.build/swiftpm_test_621.swift.o -index-store-path /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/index/store -index-system-modules
/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -modulewrap /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_621.swiftmodule -target x86_64-unknown-linux-gnu -o /root/swiftpm-test-621/.build/x86_64-unknown-linux-gnu/debug/Modules/swiftpm_test_621.o
Build complete! (9.28s)

### Incremental Build (timeout 30s)

Exit code: 124
warning: 'swiftpm-test-621': /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/swift-frontend -frontend -c -primary-file /root/swiftpm-test-621/Package.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -vfsoverlay /tmp/TemporaryDirectory.LhmHJq/vfs.yaml -no-color-diagnostics -Xcc -fno-color-diagnostics -swift-version 6 -package-description-version 6.2.0 -empty-abi-descriptor -no-auto-bridging-header-chaining -module-name main -in-process-plugin-server-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/host/libSwiftInProcPluginServer.so -plugin-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/host/plugins -plugin-path /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/local/lib/swift/host/plugins -o /tmp/TemporaryDirectory.8uaM5E/Package-1.o
/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/swift-autolink-extract /tmp/TemporaryDirectory.8uaM5E/Package-1.o -o /tmp/TemporaryDirectory.8uaM5E/main-1.autolink
/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin/clang -pie -Xlinker --build-id -Xlinker -rpath -Xlinker /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.8uaM5E/Package-1.o @/tmp/TemporaryDirectory.8uaM5E/main-1.autolink -L /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux -lswiftCore --target=x86_64-unknown-linux-gnu -v -L /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lPackageDescription -Xlinker -rpath -Xlinker /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -o /tmp/TemporaryDirectory.lDFhuM/swiftpm-test-621-manifest
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
clang version 17.0.0 (https://github.com/swiftlang/llvm-project.git 10999b6d034fe318f3d56c83bddb6572593a8bb0)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin
Found candidate GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Selected GCC installation: /usr/lib/gcc/x86_64-linux-gnu/13
Candidate multilib: .;@m64
Selected multilib: .;@m64
 "/usr/bin/ld.gold" -z relro --hash-style=gnu --eh-frame-hdr -m elf_x86_64 -pie -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o /tmp/TemporaryDirectory.lDFhuM/swiftpm-test-621-manifest /lib/x86_64-linux-gnu/Scrt1.o /lib/x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/13/crtbeginS.o -L/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux -L/tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -L/usr/lib/gcc/x86_64-linux-gnu/13 -L/usr/lib/gcc/x86_64-linux-gnu/13/../../../../lib64 -L/lib/x86_64-linux-gnu -L/lib/../lib64 -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib64 -L/lib -L/usr/lib --build-id -rpath /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/linux/x86_64/swiftrt.o /tmp/TemporaryDirectory.8uaM5E/Package-1.o -lswiftSwiftOnoneSupport -lswiftCore -lswift_Concurrency -lswift_StringProcessing -lswift_RegexParser -lswiftCore -lPackageDescription -rpath /tmp/swift-6.2.1-RELEASE-ubuntu24.04/usr/lib/swift/pm/ManifestAPI -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed /usr/lib/gcc/x86_64-linux-gnu/13/crtendS.o /lib/x86_64-linux-gnu/crtn.o
Planning build
