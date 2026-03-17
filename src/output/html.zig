// HTML Report Module - Generate vulnerability reports in HTML format

const std = @import("std");
const decompiler = @import("../decompiler/main.zig");
const vulnerability = @import("../vulnerability/scanner.zig");
const evm_signatures = @import("../evm/signatures.zig");

/// Generate HTML report from decompiled contract and vulnerability scan
pub fn generateHtmlReport(allocator: std.mem.Allocator, contract: *const decompiler.DecompiledContract, vuln_report: ?vulnerability.VulnerabilityReport, bytecode: []const u8) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    const writer = list.writer();

    // HTML Header
    try writer.writeAll("<!DOCTYPE html>\n");
    try writer.writeAll("<html lang=\"en\">\n");
    try writer.writeAll("<head>\n");
    try writer.writeAll("    <meta charset=\"UTF-8\">\n");
    try writer.writeAll("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");
    try writer.print("    <title>Security Report - {s}</title>\n", .{contract.name});
    try writer.writeAll("    <style>\n");
    try writer.writeAll(html_css_styles());
    try writer.writeAll("    </style>\n");
    try writer.writeAll("</head>\n<body>\n");

    // Header
    try writer.writeAll("<header>\n");
    try writer.writeAll("    <div class=\"container\">\n");
    try writer.print("        <h1>Solidity Decompiler Report</h1>\n", .{});
    try writer.print("        <p class=\"contract-name\">Contract: <strong>{s}</strong></p>\n", .{contract.name});
    try writer.writeAll("    </div>\n");
    try writer.writeAll("</header>\n");

    try writer.writeAll("<main class=\"container\">\n");

    // Summary Section
    try writer.writeAll("<section class=\"summary\">\n");
    try writer.writeAll("    <h2>Analysis Summary</h2>\n");
    try writer.writeAll("    <div class=\"summary-grid\">\n");
    
    if (vuln_report) |report| {
        const severity_class = if (report.risk_score >= 25) "critical" else if (report.risk_score >= 10) "high" else if (report.risk_score >= 5) "medium" else "low";
        try writer.writeAll("        <div class=\"summary-card\">\n");
        try writer.print("            <span class=\"score {s}\">{d}</span>\n", .{severity_class, @intFromFloat(report.risk_score)});
        try writer.writeAll("            <span class=\"label\">Risk Score</span>\n");
        try writer.writeAll("        </div>\n");

        try writer.writeAll("        <div class=\"summary-card\">\n");
        try writer.print("            <span class=\"number\">{d}</span>\n", .{report.vulnerabilities.len});
        try writer.writeAll("            <span class=\"label\">Vulnerabilities</span>\n");
        try writer.writeAll("        </div>\n");

        const status = if (report.is_safe) "Safe" else "At Risk";
        const status_class = if (report.is_safe) "safe" else "unsafe";
        try writer.writeAll("        <div class=\"summary-card\">\n");
        try writer.print("            <span class=\"status {s}\">{s}</span>\n", .{status_class, status});
        try writer.writeAll("            <span class=\"label\">Status</span>\n");
        try writer.writeAll("        </div>\n");
    }

    try writer.writeAll("        <div class=\"summary-card\">\n");
    try writer.print("            <span class=\"number\">{d}</span>\n", .{contract.functions.len});
    try writer.writeAll("            <span class=\"label\">Functions</span>\n");
    try writer.writeAll("        </div>\n");

    try writer.writeAll("    </div>\n");
    try writer.writeAll("</section>\n");

    // Contract Info
    try writer.writeAll("<section class=\"contract-info\">\n");
    try writer.writeAll("    <h2>Contract Information</h2>\n");
    try writer.writeAll("    <table>\n");
    try writer.writeAll("        <tr><th>Property</th><th>Value</th></tr>\n");
    try writer.print("        <tr><td>Name</td><td>{s}</td></tr>\n", .{contract.name});
    try writer.print("        <tr><td>Bytecode Size</td><td>{d} bytes</td></tr>\n", .{bytecode.len});
    try writer.print("        <tr><td>Is ERC-20</td><td>{s}</td></tr>\n", .{if (contract.is_erc20) "Yes" else "No"});
    try writer.print("        <tr><td>Is ERC-721</td><td>{s}</td></tr>\n", .{if (contract.is_erc721) "Yes" else "No"});
    try writer.print("        <tr><td>Is Proxy</td><td>{s}</td></tr>\n", .{if (contract.is_proxy) "Yes" else "No"});
    try writer.writeAll("    </table>\n");
    try writer.writeAll("</section>\n");

    // Vulnerabilities
    if (vuln_report) |report| {
        try writer.writeAll("<section class=\"vulnerabilities\">\n");
        try writer.writeAll("    <h2>Vulnerabilities</h2>\n");
        
        if (report.vulnerabilities.len == 0) {
            try writer.writeAll("    <p class=\"no-vulns\">No vulnerabilities detected!</p>\n");
        } else {
            try writer.writeAll("    <div class=\"vuln-list\">\n");
            for (report.vulnerabilities) |vuln| {
                const sev_class = switch (vuln.severity) {
                    .critical => "critical",
                    .high => "high",
                    .medium => "medium",
                    .low, .info => "low",
                };
                try writer.writeAll("        <div class=\"vuln-card\">\n");
                try writer.writeAll("            <div class=\"vuln-header\">\n");
                try writer.print("                <span class=\"severity {s}\">{s}</span>\n", .{sev_class, @tagName(vuln.severity)});
                try writer.print("                <h3>{s}</h3>\n", .{vuln.name});
                try writer.writeAll("            </div>\n");
                try writer.print("            <p class=\"description\">{s}</p>\n", .{vuln.description});
                if (vuln.cwe_id) |cwe| {
                    try writer.print("            <p class=\"cwe\">CWE: {s}</p>\n", .{cwe});
                }
                if (vuln.attack_vector) |av| {
                    try writer.print("            <p class=\"attack-vector\">Attack Vector: {s}</p>\n", .{av});
                }
                try writer.writeAll("        </div>\n");
            }
            try writer.writeAll("    </div>\n");
        }
        try writer.writeAll("</section>\n");
    }

    // Functions
    try writer.writeAll("<section class=\"functions\">\n");
    try writer.writeAll("    <h2>Detected Functions</h2>\n");
    try writer.writeAll("    <table>\n");
    try writer.writeAll("        <tr><th>Selector</th><th>Name</th><th>Signature</th></tr>\n");
    for (contract.functions) |func| {
        const selector_str = evm_signatures.selectorToSlice(func.selector);
        try writer.writeAll("        <tr>\n");
        try writer.print("            <td><code>{s}</code></td>\n", .{selector_str});
        try writer.print("            <td>{s}</td>\n", .{func.name});
        try writer.print("            <td><code>{s}</code></td>\n", .{func.signature orelse "unknown"});
        try writer.writeAll("        </tr>\n");
    }
    try writer.writeAll("    </table>\n");
    try writer.writeAll("</section>\n");

    // Footer
    try writer.writeAll("</main>\n");
    try writer.writeAll("<footer>\n");
    try writer.writeAll("    <div class=\"container\">\n");
    try writer.print("        <p>Generated by Solidity Zig Decompiler v1.0.0</p>\n", .{});
    try writer.print("        <p>Analyzed at: {d}</p>\n", .{std.time.timestamp()});
    try writer.writeAll("    </div>\n");
    try writer.writeAll("</footer>\n");

    try writer.writeAll("</body>\n</html>\n");

    return list.toOwnedSlice();
}

fn html_css_styles() []const u8 {
    return "\\* { margin: 0; padding: 0; box-sizing: border-box; } " ++
        "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0d1117; color: #c9d1d9; line-height: 1.6; } " ++
        ".container { max-width: 1200px; margin: 0 auto; padding: 20px; } " ++
        "header { background: linear-gradient(135deg, #1a1f2e 0%, #0d1117 100%); padding: 40px 0; border-bottom: 1px solid #30363d; } " ++
        "header h1 { color: #58a6ff; font-size: 2.5rem; margin-bottom: 10px; } " ++
        ".contract-name { color: #8b949e; font-size: 1.2rem; } " ++
        "main { padding: 40px 20px; } " ++
        "section { margin-bottom: 40px; } " ++
        "section h2 { color: #58a6ff; font-size: 1.8rem; margin-bottom: 20px; border-bottom: 1px solid #30363d; padding-bottom: 10px; } " ++
        ".summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; } " ++
        ".summary-card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; text-align: center; } " ++
        ".summary-card .number, .summary-card .score { font-size: 2.5rem; font-weight: bold; color: #58a6ff; } " ++
        ".summary-card .score.critical { color: #f85149; } " ++
        ".summary-card .score.high { color: #f0883e; } " ++
        ".summary-card .score.medium { color: #d29922; } " ++
        ".summary-card .score.low { color: #3fb950; } " ++
        ".summary-card .status { font-size: 1.5rem; font-weight: bold; } " ++
        ".summary-card .status.safe { color: #3fb950; } " ++
        ".summary-card .status.unsafe { color: #f85149; } " ++
        ".summary-card .label { display: block; color: #8b949e; margin-top: 5px; } " ++
        "table { width: 100%; border-collapse: collapse; background: #161b22; border-radius: 8px; overflow: hidden; } " ++
        "th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #30363d; } " ++
        "th { background: #21262d; color: #58a6ff; font-weight: 600; } " ++
        "tr:hover { background: #1c2128; } " ++
        "code { background: #0d1117; padding: 2px 6px; border-radius: 4px; color: #f0883e; font-family: 'Monaco', 'Menlo', monospace; } " ++
        ".vuln-list { display: grid; gap: 15px; } " ++
        ".vuln-card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; } " ++
        ".vuln-header { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; } " ++
        ".vuln-header h3 { color: #c9d1d9; flex: 1; } " ++
        ".severity { padding: 4px 12px; border-radius: 12px; font-size: 0.8rem; font-weight: 600; text-transform: uppercase; } " ++
        ".severity.critical { background: #f8514920; color: #f85149; border: 1px solid #f85149; } " ++
        ".severity.high { background: #f0883e20; color: #f0883e; border: 1px solid #f0883e; } " ++
        ".severity.medium { background: #d2992220; color: #d29922; border: 1px solid #d29922; } " ++
        ".severity.low { background: #3fb95020; color: #3fb950; border: 1px solid #3fb950; } " ++
        ".description { color: #8b949e; margin-bottom: 10px; } " ++
        ".cwe, .attack-vector { color: #58a6ff; font-size: 0.9rem; margin: 5px 0; } " ++
        ".no-vulns { color: #3fb950; font-size: 1.2rem; text-align: center; padding: 40px; } " ++
        "footer { background: #161b22; border-top: 1px solid #30363d; padding: 20px 0; text-align: center; color: #8b949e; } " ++
        "@media (max-width: 768px) { .summary-grid { grid-template-columns: 1fr; } table { font-size: 0.9rem; } }";
}
