#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$SCRIPT_DIR/test_workdir"
BCP="$SCRIPT_DIR/smtools/bcp.sh"

setup() {
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR/backups"
    mkdir -p "$WORK_DIR/test_data"
    echo "test content" > "$WORK_DIR/test_data/file1.sh"
    mkdir -p "$WORK_DIR/test_data/subdir"
    echo "subdir content" > "$WORK_DIR/test_data/subdir/file2.sh"
    mkdir -p "$WORK_DIR/test_data/subdir/nested"
    echo "nested content" > "$WORK_DIR/test_data/subdir/nested/file3.sh"
}

cleanup() {
    rm -rf "$WORK_DIR"
}

fail() {
    echo "FAIL: $1" >&2
    return 1
}

assert_file_exists() {
    [ -f "$1" ] || { fail "File not found: $1"; return 1; }
}

assert_file_not_exists() {
    [ ! -f "$1" ] || { fail "File should not exist: $1"; return 1; }
}

assert_equals() {
    [ "$1" = "$2" ] || { fail "Expected '$1', got '$2'"; return 1; }
}

assert_contains() {
    echo "$1" | grep -q "$2" || { fail "Expected '$1' to contain '$2'"; return 1; }
}

test_create_shallow() {
    cd "$WORK_DIR"
    "$BCP" create -s test1 || return 1
    assert_file_exists "$WORK_DIR/backups/test1.bcpdirs.txt" || return 1
    assert_file_exists "$WORK_DIR/backups/test1.backup.mode.txt" || return 1
    assert_file_not_exists "$WORK_DIR/backups/test1.bcpdirs.rec.txt" || return 1
    assert_equals "shallow" "$(cat "$WORK_DIR/backups/test1.backup.mode.txt")" || return 1
}

test_create_recursive() {
    cd "$WORK_DIR"
    "$BCP" create -r test2 || return 1
    assert_file_exists "$WORK_DIR/backups/test2.bcpdirs.rec.txt" || return 1
    assert_file_exists "$WORK_DIR/backups/test2.backup.mode.txt" || return 1
    assert_file_not_exists "$WORK_DIR/backups/test2.bcpdirs.txt" || return 1
    assert_equals "recursive" "$(cat "$WORK_DIR/backups/test2.backup.mode.txt")" || return 1
}

test_create_without_mode() {
    cd "$WORK_DIR"
    "$BCP" create test3 2>&1 | grep -q "Укажите режим" || { fail "Should require mode"; return 1; }
}

test_create_duplicate() {
    cd "$WORK_DIR"
    "$BCP" create -s test4 || return 1
    "$BCP" create -s test4 2>&1 | grep -q "Уже существует" || { fail "Should detect duplicate"; return 1; }
}

test_edit_change_mode() {
    cd "$WORK_DIR"
    "$BCP" create -s test5 || return 1
    printf "test_data\n" | "$BCP" edit -r test5 || return 1
    assert_file_exists "$WORK_DIR/backups/test5.bcpdirs.rec.txt" || return 1
    assert_file_not_exists "$WORK_DIR/backups/test5.bcpdirs.txt" || return 1
    assert_equals "shallow" "$(cat "$WORK_DIR/backups/test5.backup.mode.txt")" || return 1
}

test_backup_shallow() {
    cd "$WORK_DIR"
    "$BCP" create -s test6 || return 1
    printf "test_data\n" | "$BCP" edit test6 || return 1
    "$BCP" backup test6 || return 1
    assert_equals "shallow" "$(cat "$WORK_DIR/backups/test6.backup.mode.txt")" || return 1
    assert_file_exists "$WORK_DIR/backups/test6.bcp.json" || return 1
    ls "$WORK_DIR/backups/test6/" | grep -q "test_data_file1.sh" || { fail "Should have file1"; return 1; }
}

test_backup_recursive() {
    cd "$WORK_DIR"
    "$BCP" create -r test7 || return 1
    printf "test_data\n" | "$BCP" edit test7 || return 1
    "$BCP" backup test7 || return 1
    assert_equals "recursive" "$(cat "$WORK_DIR/backups/test7.backup.mode.txt")" || return 1
    ls "$WORK_DIR/backups/test7/" | grep -q "test_data_subdir_nested_file3.sh" || { fail "Should have nested file"; return 1; }
}

test_backup_updates_mode_from_template() {
    cd "$WORK_DIR"
    "$BCP" create -s test8 || return 1
    printf "test_data\n" | "$BCP" edit test8 || return 1
    "$BCP" edit -r test8 || return 1
    assert_equals "shallow" "$(cat "$WORK_DIR/backups/test8.backup.mode.txt")" || return 1
    "$BCP" backup test8 || return 1
    assert_equals "recursive" "$(cat "$WORK_DIR/backups/test8.backup.mode.txt")" || return 1
}

test_restore_creates_directories() {
    cd "$WORK_DIR"
    "$BCP" create -r test9 || return 1
    printf "test_data\n" | "$BCP" edit test9 || return 1
    "$BCP" backup test9 || return 1
    rm -rf "$WORK_DIR/test_data"
    mkdir -p "$WORK_DIR/test_data"
    "$BCP" restore test9 || return 1
    assert_file_exists "$WORK_DIR/test_data/subdir/nested/file3.sh" || return 1
    assert_equals "nested content" "$(cat "$WORK_DIR/test_data/subdir/nested/file3.sh")" || return 1
}

test_restore_uses_mode_from_file() {
    cd "$WORK_DIR"
    "$BCP" create -s test10 || return 1
    printf "test_data\n" | "$BCP" edit test10 || return 1
    "$BCP" backup test10 || return 1
    "$BCP" edit -r test10 || return 1
    rm -rf "$WORK_DIR/test_data"
    mkdir -p "$WORK_DIR/test_data"
    "$BCP" restore test10 || return 1
    assert_file_exists "$WORK_DIR/test_data/file1.sh" || return 1
    assert_file_not_exists "$WORK_DIR/test_data/subdir/nested/file3.sh" || return 1
}

test_delete_removes_all() {
    cd "$WORK_DIR"
    "$BCP" create -s test11 || return 1
    printf "test_data\n" | "$BCP" edit test11 || return 1
    "$BCP" backup test11 || return 1
    "$BCP" delete test11 || return 1
    assert_file_not_exists "$WORK_DIR/backups/test11.bcpdirs.txt" || return 1
    assert_file_not_exists "$WORK_DIR/backups/test11.backup.mode.txt" || return 1
    assert_file_not_exists "$WORK_DIR/backups/test11.bcp.json" || return 1
    [ ! -d "$WORK_DIR/backups/test11" ] || { fail "Backup dir should be deleted"; return 1; }
}

test_list_shows_mode() {
    cd "$WORK_DIR"
    "$BCP" create -s test12 || return 1
    "$BCP" create -r test13 || return 1
    result="$("$BCP" list)" || return 1
    assert_contains "$result" "test12 (shallow)" || return 1
    assert_contains "$result" "test13 (recursive)" || return 1
}

test_backup_with_same_content_different_names() {
    cd "$WORK_DIR"
    mkdir -p "$WORK_DIR/unique_data"
    echo "same content" > "$WORK_DIR/unique_data/a.sh"
    echo "same content" > "$WORK_DIR/unique_data/b.sh"
    "$BCP" create -s test14 || return 1
    printf "unique_data\n" | "$BCP" edit test14 || return 1
    "$BCP" backup test14 || return 1
    count=$(ls "$WORK_DIR/backups/test14/" | wc -l)
    assert_equals "2" "$count" || return 1
}

setup

tests=(
    test_create_shallow
    test_create_recursive
    test_create_without_mode
    test_create_duplicate
    test_edit_change_mode
    test_backup_shallow
    test_backup_recursive
    test_backup_updates_mode_from_template
    test_restore_creates_directories
    test_restore_uses_mode_from_file
    test_delete_removes_all
    test_list_shows_mode
    test_backup_with_same_content_different_names
)

passed=0
failed=0

for test in "${tests[@]}"; do
    echo "Running: $test"
    setup
    if $test 2>&1; then
        echo "PASS: $test"
        ((passed++))
    else
        echo "FAIL: $test"
        ((failed++))
    fi
    cleanup
done

echo ""
echo "Results: $passed passed, $failed failed"

cleanup
[ $failed -eq 0 ]