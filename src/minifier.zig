// A code golf minifier for Zig
// Reads source from stdin and prints minified source to stdout

const std = @import("std");
const Tag = std.zig.Token.Tag;

var renames: std.StringHashMap([]const u8) = undefined;
const max_source_size = 1024 * 1024; // 1MB ought to be enough for anyone

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    // Populate renames with primitive types to prevent remapping
    // Note that arbitrary length integers will be handled by the rename function
    renames = @TypeOf(renames).init(allocator);
    inline for (primitive_types) |t| {
        try renames.put(t[0], t[1]);
    }

    // Don't rename the discard identifier
    try renames.put("_", "_");
    // or the main function
    try renames.put("main", "main");

    // Read the source in
    var source_buffer = std.ArrayListAligned(u8,null).init(allocator);
    defer source_buffer.deinit();
    try std.io.getStdIn().reader().readAllArrayList(&source_buffer, max_source_size);

    // Make source null-terminated for the Tokenizer
    const source = try source_buffer.toOwnedSliceSentinel(0);
    defer allocator.free(source);
    var tokens = std.zig.Tokenizer.init(source);

    var output = std.io.getStdOut().writer();

    // We'll iterate tokens and either write them out as-is,
    //  renamed, or omitted entirely
    var tok = tokens.next();
    var prev_tag: Tag = .invalid;
    while (tok.tag != Tag.eof) : (tok = tokens.next()) {
        // If the source doesn't lex, return an error
        if (tok.tag == Tag.invalid)
            return error.invalid_source;

        // In some circumstances we'll need space between tokens,
        //  e.g. a keyword and an identifier
        if (needsSpace(prev_tag, tok.tag))
            try output.writeByte(' ');

        const content = source[tok.loc.start..tok.loc.end];
        try output.writeAll(
            switch (tok.tag) {
                // Replace identifiers with short versions
                // Avoid renaming an identifier immediately following a
                //  period (e.g. std.mem)
                //                  ^
                .identifier => if (prev_tag == Tag.period) content
                               else try rename(content),

                // We filter comments out entirely
                .doc_comment, .container_doc_comment => "",

                // Character literal to decimal
                .char_literal => try charEncode(allocator, content),

                // Everything is output as-is
                else => content
            }
        );

        prev_tag = tok.tag;
    }
}

// Renames variables and functions to short versions
fn rename(name: []const u8) ![]const u8 {
    // Have we encountered this name before?
    if (renames.get(name)) |new_name| return new_name;

    // If an arbitrary length integer type, pass through
    if ((name[0] == 'i' or name[0] == 'u') and isDigits(name[1..])) return name;

    // Pick a short name for it
    const new_name = short_names[short_name_i];
    short_name_i += 1;
    try renames.put(name, new_name);

    return new_name;
}

// True if all characters in `str` are digits
fn isDigits(str: []const u8) bool {
    for (str) |char| {
        if (!std.ascii.isDigit(char)) return false;
    }
    return true;
}

// Current short name index
var short_name_i: usize = 0;

// List of short names
const short_names = [_][]const u8{
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
};

// Where possible use the decimal representation instead of the character literal
// e.g. `'a'` => `97` saves one byte
fn charEncode(allocator: *std.mem.Allocator, char: []const u8) ![]const u8 {
    if (std.mem.eql(u8, char, "'\n'")) return "10";
    if (char.len == 3) {
        const actual_char = char[1];
        return try std.fmt.allocPrint(allocator, "{}", .{actual_char});
    }

    return char;
}

// True if `a` and `b` will need a space between them
fn needsSpace(a: Tag, b: Tag) bool {
    // identifier@Builtin is OK
    if (b == Tag.builtin) return false;

    return mightNeedSpace(a) and mightNeedSpace(b);
}

fn mightNeedSpace(t: Tag) bool {
    return switch (t) {
        .identifier,
        .builtin,
        .integer_literal,
        .float_literal,
        //.keyword_addrspace,
        .keyword_align,
        .keyword_allowzero,
        .keyword_and,
        .keyword_anyframe,
        .keyword_anytype,
        .keyword_asm,
        .keyword_async,
        .keyword_await,
        .keyword_break,
        .keyword_callconv,
        .keyword_catch,
        .keyword_comptime,
        .keyword_const,
        .keyword_continue,
        .keyword_defer,
        .keyword_else,
        .keyword_enum,
        .keyword_errdefer,
        .keyword_error,
        .keyword_export,
        .keyword_extern,
        .keyword_fn,
        .keyword_for,
        .keyword_if,
        .keyword_inline,
        .keyword_noalias,
        .keyword_noinline,
        .keyword_nosuspend,
        .keyword_opaque,
        .keyword_or,
        .keyword_orelse,
        .keyword_packed,
        .keyword_pub,
        .keyword_resume,
        .keyword_return,
        .keyword_linksection,
        .keyword_struct,
        .keyword_suspend,
        .keyword_switch,
        .keyword_test,
        .keyword_threadlocal,
        .keyword_try,
        .keyword_union,
        .keyword_unreachable,
        .keyword_usingnamespace,
        .keyword_var,
        .keyword_volatile,
        .keyword_while => true,
        else => false
    };
}

const primitive_types = .{
    // On code.golf the arch is 64bit so these two renames are good
    .{"isize","i64"},
    .{"usize","u64"},

    .{"f16","f16"},
    .{"f32","f32"},
    .{"f64","f64"},
    .{"f128","f128"},
    .{"bool","bool"},
    .{"void","void"},
    .{"noreturn","noreturn"},
    .{"type","type"},
    .{"anyerror","anyerror"},
    .{"comptime_int","comptime_int"},
    .{"comptime_float","comptime_float"},
};
