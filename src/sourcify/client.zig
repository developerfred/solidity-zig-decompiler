// ============================================================================
// Sourcify API Client
//
// Provides integration with Sourcify for fetching contract metadata and bytecode.
// See: https://docs.sourcify.dev/docs/intro
// ============================================================================

const std = @import("std");

/// Sourcify API endpoints
pub const SourcifyEndpoints = struct {
    pub const mainnet_api = "https://api.sourcify.dev";
    pub const mainnet_server = "https://sourcify.dev";

    pub const testnet_api = "https://api.testnet.sourcify.dev";
    pub const testnet_server = "https://testnet.sourcify.dev";
};

/// Chain IDs supported by Sourcify
pub const ChainId = enum(u64) {
    ethereum = 1,
    goerli = 5,
    sepolia = 11155111,
    polygon = 137,
    arbitrum_one = 42161,
    arbitrum_sepolia = 421614,
    optimism = 10,
    optimism_sepolia = 11155420,
    base = 8453,
    base_sepolia = 84532,
    avalanche = 43114,
    bsc = 56,
    gnosis = 100,
};

/// Contract metadata from Sourcify
pub const ContractMetadata = struct {
    address: []const u8,
    chain_id: u64,
    bytecode: []const u8,
    runtime_bytecode: []const u8,
    name: ?[]const u8 = null,
    compiler_version: ?[]const u8 = null,
    optimization: ?bool = null,
    runs: ?u32 = null,
    contract_name: ?[]const u8 = null,
    source_files: ?[][]const u8 = null,
};

/// Sourcify API response status
pub const VerificationStatus = enum {
    perfect,
    partial,
    none,
};

/// Sourcify API error
pub const SourcifyError = error{
    InvalidAddress,
    NetworkError,
    ContractNotFound,
    ApiError,
    ParseError,
};

/// Main Sourcify client
pub const SourcifyClient = struct {
    allocator: std.mem.Allocator,
    http_client: std.http.Client,
    base_url: []const u8,
    chain_id: ChainId,

    /// Initialize a new Sourcify client
    pub fn init(allocator: std.mem.Allocator, chain_id: ChainId) SourcifyClient {
        return .{
            .allocator = allocator,
            .http_client = std.http.Client{ .allocator = allocator },
            .base_url = SourcifyEndpoints.mainnet_api,
            .chain_id = chain_id,
        };
    }

    /// Initialize with custom endpoint
    pub fn initWithEndpoint(allocator: std.mem.Allocator, chain_id: ChainId, endpoint: []const u8) SourcifyClient {
        return .{
            .allocator = allocator,
            .http_client = std.http.Client{ .allocator = allocator },
            .base_url = endpoint,
            .chain_id = chain_id,
        };
    }

    /// Deinitialize the client
    pub fn deinit(self: *SourcifyClient) void {
        self.http_client.deinit();
    }

    /// Fetch contract bytecode by address
    pub fn fetchBytecode(self: *SourcifyClient, address: []const u8) !ContractMetadata {
        // Validate address
        if (address.len != 42 or !std.mem.startsWith(u8, address, "0x")) {
            return SourcifyError.InvalidAddress;
        }

        const chain_id_num = @intFromEnum(self.chain_id);

        // Build URL: /contracts/full/{chainId}/{address}
        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(self.base_url);
        try url_buf.appendSlice("/contracts/full/");
        try url_buf.appendSlice(std.fmt.allocPrintZ(self.allocator, "{}", .{chain_id_num}) catch "");
        try url_buf.appendSlice("/");
        try url_buf.appendSlice(address);

        const url = try std.Uri.parse(url_buf.items);

        // Make request
        var header_buffer: [256]u8 = undefined;
        var request = try self.http_client.request(.GET, url, .{
            .header_buffer = &header_buffer,
        }, .{});
        defer request.deinit();

        try request.start();
        try request.wait();

        switch (request.response.status) {
            .ok => {
                // Read response body
                const body = try request.reader().readAllAlloc(self.allocator, 1024 * 1024);
                defer self.allocator.free(body);

                return try self.parseContractResponse(address, chain_id_num, body);
            },
            .not_found => {
                return SourcifyError.ContractNotFound;
            },
            else => {
                return SourcifyError.ApiError;
            },
        }
    }

    /// Check if contract is verified on Sourcify
    pub fn checkVerification(self: *SourcifyClient, address: []const u8) !VerificationStatus {
        if (address.len != 42 or !std.mem.startsWith(u8, address, "0x")) {
            return SourcifyError.InvalidAddress;
        }

        const chain_id_num = @intFromEnum(self.chain_id);

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(self.base_url);
        try url_buf.appendSlice("/checkverification/");
        try url_buf.appendSlice(std.fmt.allocPrintZ(self.allocator, "{}", .{chain_id_num}) catch "");
        try url_buf.appendSlice("/");
        try url_buf.appendSlice(address);

        const url = try std.Uri.parse(url_buf.items);

        var header_buffer: [256]u8 = undefined;
        var request = try self.http_client.request(.GET, url, .{
            .header_buffer = &header_buffer,
        }, .{});
        defer request.deinit();

        try request.start();
        try request.wait();

        const body = try request.reader().readAllAlloc(self.allocator, 8192);
        defer self.allocator.free(body);

        // Parse JSON response
        // Simplified: check for "perfect" or "partial" in response
        if (std.mem.indexOf(u8, body, "\"status\":\"perfect\"") != null) {
            return .perfect;
        } else if (std.mem.indexOf(u8, body, "\"status\":\"partial\"") != null) {
            return .partial;
        }

        return .none;
    }

    /// Get list of all verified contracts on a chain
    pub fn listContracts(self: *SourcifyClient) ![][]const u8 {
        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(self.base_url);
        try url_buf.appendSlice("/contracts/");

        const url = try std.Uri.parse(url_buf.items);

        var header_buffer: [256]u8 = undefined;
        var request = try self.http_client.request(.GET, url, .{
            .header_buffer = &header_buffer,
        }, .{});
        defer request.deinit();

        try request.start();
        try request.wait();

        const body = try request.reader().readAllAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(body);

        // Return addresses (simplified - would need proper JSON parsing)
        return &.{};
    }

    /// Parse contract response from Sourcify API
    fn parseContractResponse(_self: *SourcifyClient, address: []const u8, chain_id: u64, body: []const u8) !ContractMetadata {
        _ = _self;
        // Simple JSON parsing for key fields
        // Simple JSON parsing for key fields
        var metadata = ContractMetadata{
            .address = address,
            .chain_id = chain_id,
            .bytecode = "",
            .runtime_bytecode = "",
        };

        // Find bytecode in response
        if (std.mem.indexOf(u8, body, "\"bytecode\"") != null) {
            // Extract bytecode value - simplified
            const start = std.mem.indexOf(u8, body, "\"bytecode\":\"") orelse return SourcifyError.ParseError;
            const value_start = start + 11;
            const end = std.mem.indexOfPos(u8, body, value_start, "\"") orelse body.len;
            if (end > value_start) {
                metadata.bytecode = body[value_start..end];
            }
        }

        // Find runtime bytecode
        if (std.mem.indexOf(u8, body, "\"runtimeBytecode\"") != null) {
            const start = std.mem.indexOf(u8, body, "\"runtimeBytecode\":\"") orelse return SourcifyError.ParseError;
            const value_start = start + 17;
            const end = std.mem.indexOfPos(u8, body, value_start, "\"") orelse body.len;
            if (end > value_start) {
                metadata.runtime_bytecode = body[value_start..end];
            }
        }

        // Find contract name
        if (std.mem.indexOf(u8, body, "\"name\":\"") != null) {
            const start = std.mem.indexOf(u8, body, "\"name\":\"") orelse return SourcifyError.ParseError;
            const value_start = start + 7;
            const end = std.mem.indexOfPos(u8, body, value_start, "\"") orelse body.len;
            if (end > value_start) {
                metadata.name = body[value_start..end];
            }
        }

        return metadata;
    }
};

/// Fetch bytecode from Sourcify by address (convenience function)
pub fn fetchBytecodeByAddress(allocator: std.mem.Allocator, address: []const u8, chain_id: ChainId) !ContractMetadata {
    var client = SourcifyClient.init(allocator, chain_id);
    defer client.deinit();

    return try client.fetchBytecode(address);
}

/// Check if contract is verified (convenience function)
pub fn checkVerified(allocator: std.mem.Allocator, address: []const u8, chain_id: ChainId) !VerificationStatus {
    var client = SourcifyClient.init(allocator, chain_id);
    defer client.deinit();

    return try client.checkVerification(address);
}
