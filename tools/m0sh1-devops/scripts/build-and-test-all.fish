#!/usr/bin/env fish

# Build and test all Go devops tools

set -l SCRIPT_DIR (realpath (dirname (status --current-filename)) 2>/dev/null)
if test $status -ne 0; or test -z "$SCRIPT_DIR"
    echo "❌ Failed to resolve script directory"
    exit 1
end
cd $SCRIPT_DIR

set -l TOOLS helm-scaffold terraform-lab-guard gitops-guard check-idempotency sensitive-files-guard path-drift-guard

echo "🔨 Building and testing all Go devops tools..."
echo ""

set -l BUILD_SUCCESS 0
set -l BUILD_FAILED 0
set -l TEST_SUCCESS 0
set -l TEST_FAILED 0

for tool in $TOOLS
    if not test -d $tool
        echo "⚠️  $tool directory not found, skipping"
        echo ""
        continue
    end

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Processing: $tool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cd $tool

    # Build
    echo "🔨 Building..."
    env CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o $tool .

    if test $status -eq 0
        echo "   ✅ Build successful"
        set BUILD_SUCCESS (math $BUILD_SUCCESS + 1)

        # Show binary info
        set -l size (ls -lh $tool | awk '{print $5}')
        echo "   📏 Size: $size"
        echo ""

        # Test based on tool type
        echo "🧪 Testing..."

        set -l test_ok 1

        switch $tool
            case helm-scaffold
                echo "   Testing --help flag:"
                ./helm-scaffold -help 2>&1 | head -n 5
                set -l cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end
                echo ""
                echo "   Testing repo detection (expected failure):"
                ./helm-scaffold -repo /nonexistent -name test 2>&1 | head -n 3
                set cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end

            case terraform-lab-guard
                echo "   Testing --help flag:"
                ./terraform-lab-guard -help 2>&1 | head -n 5
                set -l cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end
                echo ""
                echo "   Testing validation (expected failure on nonexistent repo):"
                ./terraform-lab-guard -repo /nonexistent 2>&1 | head -n 3
                set cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end

            case gitops-guard
                echo "   Testing --help flag:"
                ./gitops-guard -help 2>&1 | head -n 5
                set -l cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end
                echo ""
                echo "   Testing validation (expected failure on nonexistent repo):"
                ./gitops-guard -repo /nonexistent 2>&1 | head -n 3
                set cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end

            case check-idempotency
                echo "   Testing --help flag:"
                ./check-idempotency -h 2>&1 | head -n 8
                set -l cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end
                echo ""
                echo "   Testing validation (expected usage error):"
                ./check-idempotency 2>&1 | head -n 3
                set cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end

            case sensitive-files-guard
                echo "   Testing --help flag:"
                ./sensitive-files-guard -h 2>&1 | head -n 8
                set -l cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end
                echo ""
                echo "   Testing list-patterns:"
                ./sensitive-files-guard -list-patterns 2>&1 | head -n 5
                set cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end

            case path-drift-guard
                echo "   Testing --version flag:"
                ./path-drift-guard -version 2>&1 | head -n 3
                set -l cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end
                echo ""
                echo "   Testing list-allowlist:"
                ./path-drift-guard -list-allowlist 2>&1 | head -n 10
                set cmd_status $pipestatus[1]
                if not contains -- $cmd_status 0 1 2
                    set test_ok 0
                end
        end

        if test $test_ok -eq 1
            echo ""
            echo "   ✅ Basic tests passed"
            set TEST_SUCCESS (math $TEST_SUCCESS + 1)
        else
            echo ""
            echo "   ❌ Tests failed or returned unexpected exit codes"
            set TEST_FAILED (math $TEST_FAILED + 1)
        end

    else
        echo "   ❌ Build failed!"
        set BUILD_FAILED (math $BUILD_FAILED + 1)
        set TEST_FAILED (math $TEST_FAILED + 1)
    end

    cd ..
    echo ""
end

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Final Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 Builds:"
echo "   ✅ Success: $BUILD_SUCCESS"
echo "   ❌ Failed: $BUILD_FAILED"
echo ""
echo "🧪 Tests:"
echo "   ✅ Success: $TEST_SUCCESS"
echo "   ❌ Failed: $TEST_FAILED"
echo ""

if test $BUILD_FAILED -gt 0; or test $TEST_FAILED -gt 0
    echo "❌ Some builds or tests failed!"
    exit 1
else
    echo "✅ All builds and tests successful!"
    echo ""
    echo "📋 Built tools:"
    echo "   • helm-scaffold/helm-scaffold"
    echo "   • terraform-lab-guard/terraform-lab-guard"
    echo "   • gitops-guard/gitops-guard"
    echo "   • check-idempotency/check-idempotency"
    echo "   • sensitive-files-guard/sensitive-files-guard"
    echo ""

    # Deploy CI-used binaries to tools/ci/
    echo "📦 Deploying binaries to tools/ci/..."
    set -l CI_DIR (realpath ../../ci 2>/dev/null)
    if test $status -ne 0; or not test -d $CI_DIR
        echo "❌ tools/ci not found: $CI_DIR"
        exit 1
    end
    set -l CI_TOOLS check-idempotency sensitive-files-guard path-drift-guard
    set -l DEPLOYED 0

    for tool in $CI_TOOLS
        if test -f "$tool/$tool"
            cp "$tool/$tool" "$CI_DIR/"
            chmod +x "$CI_DIR/$tool"
            if type -q xattr
                xattr -dr com.apple.quarantine "$CI_DIR/$tool" 2>/dev/null
            end
            if type -q codesign
                codesign --force --sign - --timestamp=none "$CI_DIR/$tool"
                if test $status -ne 0
                    echo "   ❌ codesign failed: $CI_DIR/$tool"
                    exit 1
                end
            end
            echo "   ✅ Deployed: $CI_DIR/$tool"
            set DEPLOYED (math $DEPLOYED + 1)
        else
            echo "   ⚠️  Skipped: $tool (binary not found)"
            set TEST_FAILED (math $TEST_FAILED + 1)
        end
    end

    if test $DEPLOYED -ne (count $CI_TOOLS)
        echo "   ❌ CI deployment incomplete"
        exit 1
    end

    echo ""
    echo "   📊 Deployed $DEPLOYED/3 CI binaries"
    echo ""

    echo "🚀 Ready for production use!"
    echo ""
    echo "📖 Usage examples:"
    echo "   helm-scaffold -repo . -scope user -name app -argocd"
    echo "   terraform-lab-guard -repo ."
    echo "   gitops-guard -repo ."
    echo "   check-idempotency ansible/playbooks/*.yaml"
    echo "   sensitive-files-guard"
    echo ""
    echo "🔧 CI integration:"
    echo "   tools/ci/check-idempotency ansible/playbooks/*.yaml"
    echo "   tools/ci/sensitive-files-guard"
    echo "   tools/ci/path-drift-guard"
    echo ""
end
