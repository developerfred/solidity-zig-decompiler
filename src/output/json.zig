// JSON Output Module - For integration with external tools

const std = @import("std");
const decompiler = @import("../decompiler/main.zig");
const vulnerability = @import("../vulnerability/scanner.zig");
const evm_signatures = @import("../evm/signatures.zig");

pub const OutputFormat = enum {
    solidity,
    json,
    html,
    diff,
};

pub const JsonOutput = struct {
    version: []const u8 = "1.0.0",
    contract: ContractInfo,
    vulnerabilities: ?VulnerabilityInfo,
    metadata: MetadataInfo,
};

pub const ContractInfo = struct {
    name: []const u8,
    bytecode_length: usize,
    is_proxy: bool,
    is_erc20: bool,
    is_erc721: bool,
    functions: []FunctionInfo,
    embedded_strings: []EmbeddedStringInfo,
};

pub const FunctionInfo = struct {
    name: []const u8,
    selector: []const u8,
    signature: ?[]const u8,
};

pub const EmbeddedStringInfo = struct {
    value: []const u8,
    offset: usize,
};

pub const VulnerabilityInfo = struct {
    vulnerabilities: []VulnerabilityItem,
    is_safe: bool,
    risk_score: f32,
    total_count: usize,
};

pub const VulnerabilityItem = struct {
    cwe_id: ?[]const u8,
    name: []const u8,
    description: []const u8,
    severity: []const u8,
    location: ?usize,
    attack_vector: ?[]const u8,
};

pub const MetadataInfo = struct {
    analyzed_at: i64,
    analyzer_version: []const u8,
    output_format: []const u8,
};

/// Generate JSON output from decompiled contract
pub fn generateJson(allocator: std.mem.Allocator, contract: *const decompiler.DecompiledContract, vuln_report: ?vulnerability.VulnerabilityReport) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    const writer = list.writer();

    try writer.writeAll("{\n");
    
    // Version
    try writer.writeAll("  \"version\": \"1.0.0\",\n");

    // Contract info
    try writer.writeAll("  \"contract\": {\n");
    try writer.print("    \"name\": \"{s}\",\n", .{contract.name});
    try writer.print("    \"bytecode_length\": {d},\n", .{contract.functions.len * 4}); // Approximate
    try writer.print("    \"is_proxy\": {},\n", .{contract.is_proxy});
    try writer.print("    \"is_erc20\": {},\n", .{contract.is_erc20});
    try writer.print("    \"is_erc721\": {},\n", .{contract.is_erc721});

    // Functions
    try writer.writeAll("    \"functions\": [\n");
    for (contract.functions, 0..) |func, i| {
        const selector_str = evm_signatures.selectorToSlice(func.selector);
        try writer.writeAll("      {\n");
        try writer.print("        \"name\": \"{s}\",\n", .{func.name});
        try writer.print("        \"selector\": \"{s}\",\n", .{selector_str});
        if (func.signature) |sig| {
            try writer.print("        \"signature\": \"{s}\"\n", .{sig});
        } else {
            try writer.writeAll("        \"signature\": null\n");
        }
        try writer.writeAll("      }");
        if (i < contract.functions.len - 1) try writer.writeAll(",");
        try writer.writeAll("\n");
    }
    try writer.writeAll("    ],\n");

    // Embedded strings
    try writer.writeAll("    \"embedded_strings\": [\n");
    for (contract.embedded_strings, 0..) |str, i| {
        try writer.writeAll("      {\n");
        try writer.print("        \"value\": \"{s}\",\n", .{str.value});
        try writer.print("        \"offset\": {d}\n", .{str.offset});
        try writer.writeAll("      }");
        if (i < contract.embedded_strings.len - 1) try writer.writeAll(",");
        try writer.writeAll("\n");
    }
    try writer.writeAll("    ]\n");

    try writer.writeAll("  },\n");

    // Vulnerabilities
    if (vuln_report) |report| {
        try writer.writeAll("  \"vulnerabilities\": {\n");
        try writer.print("    \"is_safe\": {},\n", .{report.is_safe});
        try writer.print("    \"risk_score\": {d},\n", .{report.risk_score});
        try writer.print("    \"total_count\": {d},\n", .{report.vulnerabilities.len});

        try writer.writeAll("    \"items\": [\n");
        for (report.vulnerabilities, 0..) |vuln, i| {
            try writer.writeAll("      {\n");
            if (vuln.cwe_id) |cwe| {
                try writer.print("        \"cwe_id\": \"{s}\",\n", .{cwe});
            } else {
                try writer.writeAll("        \"cwe_id\": null,\n");
            }
            try writer.print("        \"name\": \"{s}\",\n", .{vuln.name});
            try writer.print("        \"description\": \"{s}\",\n", .{vuln.description});
            try writer.print("        \"severity\": \"{s}\",\n", .{
                @tagName(vuln.severity)
            });
            if (vuln.location) |loc| {
                try writer.print("        \"location\": {d},\n", .{loc});
            } else {
                try writer.writeAll("        \"location\": null,\n");
            }
            if (vuln.attack_vector) |av| {
                try writer.print("        \"attack_vector\": \"{s}\"\n", .{av});
            } else {
                try writer.writeAll("        \"attack_vector\": null\n");
            }
            try writer.writeAll("      }");
            if (i < report.vulnerabilities.len - 1) try writer.writeAll(",");
            try writer.writeAll("\n");
        }
        try writer.writeAll("    ]\n");

        try writer.writeAll("  }\n");
    } else {
        try writer.writeAll("  \"vulnerabilities\": null\n");
    }

    // Metadata
    try writer.writeAll("  \"metadata\": {\n");
    try writer.print("    \"analyzed_at\": {d},\n", .{std.time.timestamp()});
    try writer.writeAll("    \"analyzer_version\": \"1.0.0\",\n");
    try writer.writeAll("    \"output_format\": \"json\"\n");
    try writer.writeAll("  }\n");

    try writer.writeAll("}\n");

    return list.toOwnedSlice();
}

/// Format severity as string
fn severityToString(severity: vulnerability.Severity) []const u8 {
    return switch (severity) {
        .info => "info",
        .low => "low",
        .medium => "medium",
        .high => "high",
        .critical => "critical",
    };
}
