// Function Signature Resolver - Extended with DeFi and Flash Loan Signatures

const std = @import("std");

pub const ResolvedSignature = struct {
    selector: [4]u8,
    signature: []const u8,
    confidence: f32,
    source: SignatureSource,
};

pub const SignatureSource = enum { builtin, api, inferred, unknown };

pub const SignatureCache = struct {
    entries: std.StringHashMap(ResolvedSignature),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SignatureCache {
        return .{
            .entries = std.StringHashMap(ResolvedSignature).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SignatureCache) void {
        self.entries.deinit();
    }
};

// ============================================================================
// Flash Loan Signatures
// ============================================================================

fn lookupFlashLoanSignature(hex: []const u8) ?[]const u8 {
    // Aave V2
    if (std.mem.eql(u8, hex, "0x5cdea6c5")) return "flashLoan(address,address,uint256,bytes)";
    if (std.mem.eql(u8, hex, "0x155f51e9")) return "flashLoanSimple(address,uint256,bytes,uint16)";

    // Aave V3
    if (std.mem.eql(u8, hex, "0x0d4fd0cb")) return "flash(address,address,uint256,uint256,bytes)";
    if (std.mem.eql(u8, hex, "0xae30e5a4")) return "flashSimple(uint256,address,bytes)";

    // Aave - executeOperation (callback)
    if (std.mem.eql(u8, hex, "0x9b2eb4ee")) return "executeOperation(address[],uint256[],uint256[],address,bytes)";
    if (std.mem.eql(u8, hex, "0x436ad9e8")) return "executeOperation(address,uint256,uint256,address,bytes)";

    // Uniswap V2 - Flash Swaps
    if (std.mem.eql(u8, hex, "0x0902f1ac")) return "swap(uint256,uint256,address,bytes)";

    // Uniswap V3 - Flash
    if (std.mem.eql(u8, hex, "0x2e1a7d4d")) return "flash(address,uint256,bytes)";
    if (std.mem.eql(u8, hex, "0x3c4d2d2e")) return "flashFee(address,uint256)";

    // dYdX
    if (std.mem.eql(u8, hex, "0x3b5a7d0e")) return "flashLoan(address,uint256,bytes)"; // SoloMargin

    // Euler
    if (std.mem.eql(u8, hex, "0x76b5c2ac")) return "flashLoan(address,uint256,bytes)";
    if (std.mem.eql(u8, hex, "0x5ce8d2a7")) return "onFlashLoan(bytes)";

    // Balancer V2
    if (std.mem.eql(u8, hex, "0xab5f7b67")) return "flashLoan(address,uint256,bytes)";
    if (std.mem.eql(u8, hex, "0x5e4c3ef1")) return "onFlashLoan(address,uint256,uint256,bytes)";

    // Yearn
    if (std.mem.eql(u8, hex, "0xc04d1d1d")) return "flashLoan(uint256,address,bytes)"; // yVault

    return null;
}

// ============================================================================
// DeFi Protocol Signatures
// ============================================================================

fn lookupDefiSignature(hex: []const u8) ?[]const u8 {
    // Uniswap V2
    if (std.mem.eql(u8, hex, "0xd78ad95f")) return "swap(uint256,uint256,address,address,uint256,uint256)";
    if (std.mem.eql(u8, hex, "0x18cbafe5")) return "swapExactETHForTokens(uint256,address[],address,uint256)";
    if (std.mem.eql(u8, hex, "0x7ff36ab5")) return "swapExactETHForTokens(uint256,address[],address,uint256)"; // V2 router
    if (std.mem.eql(u8, hex, "0xfb3bdb41")) return "swapExactTokensForETH(uint256,uint256,address[],address,uint256)";
    if (std.mem.eql(u8, hex, "0x4a25d94a")) return "swapExactTokensForETH(uint256,uint256,address[],address,uint256)";
    if (std.mem.eql(u8, hex, "0xb6f9de95")) return "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)";
    if (std.mem.eql(u8, hex, "0x38ed1739")) return "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)";
    if (std.mem.eql(u8, hex, "0x8803dbee")) return "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)";
    if (std.mem.eql(u8, hex, "0xf305d719")) return "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)";
    if (std.mem.eql(u8, hex, "0xe8e33700")) return "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)";
    if (std.mem.eql(u8, hex, "0xbaa2abde")) return "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)";
    if (std.mem.eql(u8, hex, "0xaf2979eb")) return "removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)";

    // Uniswap V3
    if (std.mem.eql(u8, hex, "0x414bf389")) return "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))";
    if (std.mem.eql(u8, hex, "0xb0431182")) return "exactInput((bytes,address,uint256,uint256,uint256))";
    if (std.mem.eql(u8, hex, "0x4f1eb3d8")) return "exactOutputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))";
    if (std.mem.eql(u8, hex, "0xf28c0498")) return "exactOutput((bytes,address,uint256,uint256,uint256))";
    if (std.mem.eql(u8, hex, "0x0d49ef6c")) return "multicall(uint256,bytes[])";
    if (std.mem.eql(u8, hex, "0xac9650d8")) return "multicall(bytes[])";
    if (std.mem.eql(u8, hex, "0x219f5d17")) return "mint((address,int24,int24,uint256,uint160))";

    // Aave V2
    if (std.mem.eql(u8, hex, "0x4c4a7fcd")) return "deposit(address,uint256)";
    if (std.mem.eql(u8, hex, "0x2608f818")) return "withdraw(address,uint256)";
    if (std.mem.eql(u8, hex, "0x0c34a2a5")) return "borrow(address,uint256,uint256,uint16,address)";
    if (std.mem.eql(u8, hex, "0x5ce8d2a7")) return "repay(address,uint256,uint256,address)";
    if (std.mem.eql(u8, hex, "0x18c4f6b4")) return "setUserUseReserveAsCollateral(address,bool)";

    // Aave V3
    if (std.mem.eql(u8, hex, "0x573ade81")) return "supplyWithPermit(address,uint256,address,uint16,uint256,uint8,bytes32,bytes32)";
    if (std.mem.eql(u8, hex, "0x2b47d7f6")) return "withdraw(address,uint256,address,uint16)";
    if (std.mem.eql(u8, hex, "0x013e2e14")) return "setUserEMode(uint8)";
    if (std.mem.eql(u8, hex, "0x1e8d3f4f")) return "initReserve(address,address,address,address,address)";

    // Compound V2
    if (std.mem.eql(u8, hex, "0xa0712d68")) return "mint(uint256)"; // cToken mint
    if (std.mem.eql(u8, hex, "0x0e752702")) return "redeem(uint256)"; // cToken redeem
    if (std.mem.eql(u8, hex, "0xdb006a75")) return "redeemUnderlying(uint256)";
    if (std.mem.eql(u8, hex, "0x4ce3f59a")) return "borrow(uint256)"; // cToken borrow
    if (std.mem.eql(u8, hex, "0x870408d6")) return "repayBorrow(uint256)";
    if (std.mem.eql(u8, hex, "0x24008575")) return "repayBehalf(address,uint256)";
    if (std.mem.eql(u8, hex, "0xca5072d9")) return "liquidateBorrow(address,address,uint256)";

    // Compound V3 (Comet)
    if (std.mem.eql(u8, hex, "0xf2b90f97")) return "supply(address,uint256)";
    if (std.mem.eql(u8, hex, "0x223d6d39")) return "withdraw(address,uint256)";
    if (std.mem.eql(u8, hex, "0x3a1a7ede")) return "liquidate(address,address,uint256)";
    if (std.mem.eql(u8, hex, "0x9a1e5c53")) return "absorb(address,address[])";

    // Curve
    if (std.mem.eql(u8, hex, "0x4515cef3")) return "add_liquidity(uint256[],uint256)";
    if (std.mem.eql(u8, hex, "0x1e4a8ef5")) return "remove_liquidity(uint256,uint256[])";
    if (std.mem.eql(u8, hex, "0x1e4a8374")) return "remove_liquidity_one_coin(uint256,int128,uint256)";
    if (std.mem.eql(u8, hex, "0xa41f6d44")) return "exchange(int128,int128,uint256,uint256)";
    if (std.mem.eql(u8, hex, "0x3ece8018")) return "get_dy(int128,int128,uint256)";
    if (std.mem.eql(u8, hex, "0x07211ef3")) return "get_dy_underlying(int128,int128,uint256)";

    // Lido
    if (std.mem.eql(u8, hex, "0x3ca7b03d")) return "submit(address)"; // stETH submit
    if (std.mem.eql(u8, hex, "0x80c0c5b4")) return "withdraw(uint256,address)"; // stETH withdraw
    if (std.mem.eql(u8, hex, "0x24c11f8c")) return "wrap(uint256)"; // wstETH wrap
    if (std.mem.eql(u8, hex, "0x6c2f8b10")) return "unwrap(uint256)"; // wstETH unwrap

    // Yearn Vaults
    if (std.mem.eql(u8, hex, "0x6e553f65")) return "deposit(uint256,address)"; // yVault
    if (std.mem.eql(u8, hex, "0x3ccfd60b")) return "withdraw(uint256,address,uint256)";
    if (std.mem.eql(u8, hex, "0x464b7c28")) return "earn()"; // yVault earn

    // Gnosis Safe
    if (std.mem.eql(u8, hex, "0xb63e800d")) return "setup(address[],uint256,address,bytes,address,address,uint256,address)";
    if (std.mem.eql(u8, hex, "0x6101e604")) return "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)";
    if (std.mem.eql(u8, hex, "0x6a761202")) return "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)";
    if (std.mem.eql(u8, hex, "0x2f2ff05c")) return "addOwnerWithThreshold(address,uint256)";
    if (std.mem.eql(u8, hex, "0x0e79a2be")) return "removeOwner(address,address,uint256)";

    // Proxy Patterns
    if (std.mem.eql(u8, hex, "0x4f1ef386")) return "upgradeToAndCall(address,bytes)"; // UUPS upgrade
    if (std.mem.eql(u8, hex, "0x3659cfe6")) return "upgradeTo(address)"; // UUPS
    if (std.mem.eql(u8, hex, "0x8a6a58b6")) return "implementation()"; // Transparent
    if (std.mem.eql(u8, hex, "0x5c60da1b")) return "proxyType()"; // ERC1822
    if (std.mem.eql(u8, hex, "0x54d1c43e")) return "proxiableUUID()"; // ERC1822 UUPS

    // Diamond Standard (EIP-2535)
    if (std.mem.eql(u8, hex, "0x1f931c1c")) return "diamondCut((address,uint8,bytes4[])[],address,bytes)";
    if (std.mem.eql(u8, hex, "0xcdffacc6")) return "facetAddress(bytes4)";
    if (std.mem.eql(u8, hex, "0x52ef6b2c")) return "facetAddresses()";
    if (std.mem.eql(u8, hex, "0xadfca15e")) return "facetFunctionSelectors(address)";

    // Li.FI Protocol (Cross-chain liquidity aggregation)
    // Li.FI Diamond: 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE
    if (std.mem.eql(u8, hex, "0xa1257d8f")) return "swapTokensGeneric((address,address,address,uint256,uint256,uint256,address,bytes)[],(address,address,address,address,uint256,bytes,address,address,uint256,bytes)[],(address,address,address,address,uint256,bool,address,bytes)[],address,address)";
    if (std.mem.eql(u8, hex, "0x7c665dfc")) return "startBridgeTokensViaLiFi((address,address,address,uint256,uint256,address,bytes),(address,uint256,address,bytes))";
    if (std.mem.eql(u8, hex, "0x1e1d1d6f")) return "swapAndStartBridgeTokensViaLiFi((address,address,address,uint256,uint256,address,bytes),(address,uint256,address,bytes))";
    if (std.mem.eql(u8, hex, "0x0d4fd0cb")) return "swapAndStartBridgeTokensViaLiFi((address,address,uint256,uint256,bytes),address,uint256,address,bytes)";
    if (std.mem.eql(u8, hex, "0x2a1ec87e")) return "startBridgeTokensGeneric((address,address,address,uint256,uint256,address,bytes),(address,uint256,address,bytes),address)";
    if (std.mem.eql(u8, hex, "0x3be2a24b")) return "swapAndStartBridgeTokensGeneric((address,address,address,uint256,uint256,address,bytes)[],(address,address,address,address,uint256,bool,address,bytes)[],(address,address,address,address,uint256,bytes,address,address,uint256,bytes)[],address)";
    if (std.mem.eql(u8, hex, "0x54787c40")) return "swap((address,address,address,uint256,uint256,address))";
    if (std.mem.eql(u8, hex, "0x2f2ff05c")) return "addFacet((address,uint8,bytes4[],address,bytes))";

    // Beacon Proxy
    if (std.mem.eql(u8, hex, "0x5f360067")) return "beacon()"; // Beacon proxy
    if (std.mem.eql(u8, hex, "0x2d0335ab")) return "upgradeBeaconToAndCall(address,bytes)";

    // ERC-4337 (Account Abstraction)
    if (std.mem.eql(u8, hex, "0x2f63c8a9")) return "validateUserOp((address,uint256,bytes,bytes32),(bytes32,uint256))";
    if (std.mem.eql(u8, hex, "0x64c9acad")) return "execute(bytes32,uint256,bytes)";
    if (std.mem.eql(u8, hex, "0x8ef3a9f9")) return "executeBatch((address,uint256,bytes)[])";
    if (std.mem.eql(u8, hex, "0xcffb3d53")) return "addStake(uint32)";
    if (std.mem.eql(u8, hex, "0x09635f0b")) return "lockStake(uint32)";
    if (std.mem.eql(u8, hex, "0x2e2347ae")) return "unlockStake()";

    return null;
}

// ============================================================================
// Basic ERC Signatures
// ============================================================================

fn lookupBasicSignature(hex: []const u8) ?[]const u8 {
    // ERC-20
    if (std.mem.eql(u8, hex, "0xa9059cbb")) return "transfer(address,uint256)";
    if (std.mem.eql(u8, hex, "0x095ea7b3")) return "approve(address,uint256)";
    if (std.mem.eql(u8, hex, "0x23b872dd")) return "transferFrom(address,address,uint256)";
    if (std.mem.eql(u8, hex, "0xdd62ed3e")) return "allowance(address,address)";
    if (std.mem.eql(u8, hex, "0x18160ddd")) return "totalSupply()";
    if (std.mem.eql(u8, hex, "0x70a08231")) return "balanceOf(address)";
    if (std.mem.eql(u8, hex, "0xa457c2d7")) return "decreaseAllowance(address,uint256)";
    if (std.mem.eql(u8, hex, "0x39509351")) return "increaseAllowance(address,uint256)";

    // ERC-721
    if (std.mem.eql(u8, hex, "0x6352211e")) return "ownerOf(uint256)";
    if (std.mem.eql(u8, hex, "0x42842e0e")) return "safeTransferFrom(address,address,uint256)";
    if (std.mem.eql(u8, hex, "0xb88d4fde")) return "safeTransferFrom(address,address,uint256,bytes)";
    if (std.mem.eql(u8, hex, "0x081812fc")) return "setApprovalForAll(address,bool)";
    if (std.mem.eql(u8, hex, "0xe985e9c5")) return "isApprovedForAll(address,address)";
    if (std.mem.eql(u8, hex, "0xc87b56dc")) return "tokenURI(uint256)";

    // ERC-1155
    if (std.mem.eql(u8, hex, "0xf242432a")) return "safeTransferFrom(address,address,uint256,uint256,bytes)";
    if (std.mem.eql(u8, hex, "0x2eb2c2d6")) return "safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)";
    if (std.mem.eql(u8, hex, "0x4e2312e0")) return "onERC1155Received(address,address,uint256,uint256,bytes)";

    // Ownable
    if (std.mem.eql(u8, hex, "0x8da5cb5b")) return "owner()";
    if (std.mem.eql(u8, hex, "0xf2fde38b")) return "transferOwnership(address)";
    if (std.mem.eql(u8, hex, "0x3659cfe6")) return "renounceOwnership()";

    // Pausable
    if (std.mem.eql(u8, hex, "0x5c60da1b")) return "paused()";
    if (std.mem.eql(u8, hex, "0x8456cb59")) return "pause()";
    if (std.mem.eql(u8, hex, "0x3f4ba83a")) return "unpause()";

    // ERC-165
    if (std.mem.eql(u8, hex, "0x01ffc9a7")) return "supportsInterface(bytes4)";

    // ERC-20/721 Metadata
    if (std.mem.eql(u8, hex, "0x06fdde03")) return "name()";
    if (std.mem.eql(u8, hex, "0x95d89b41")) return "symbol()";
    if (std.mem.eql(u8, hex, "0x313ce567")) return "decimals()";

    return null;
}

pub fn resolve(selector: [4]u8, cache: *SignatureCache) !ResolvedSignature {
    const hex = selectorToHex(selector);
    const hex_slice: []const u8 = &hex;

    if (cache.entries.get(hex_slice)) |*cached| return cached.*;

    // Priority: Flash Loans > DeFi > Basic ERC
    if (lookupFlashLoanSignature(hex_slice)) |sig| {
        const resolved = ResolvedSignature{
            .selector = selector,
            .signature = sig,
            .confidence = 1.0,
            .source = .builtin,
        };
        try cache.entries.put(hex_slice, resolved);
        return resolved;
    }

    if (lookupDefiSignature(hex_slice)) |sig| {
        const resolved = ResolvedSignature{
            .selector = selector,
            .signature = sig,
            .confidence = 1.0,
            .source = .builtin,
        };
        try cache.entries.put(hex_slice, resolved);
        return resolved;
    }

    if (lookupBasicSignature(hex_slice)) |sig| {
        const resolved = ResolvedSignature{
            .selector = selector,
            .signature = sig,
            .confidence = 1.0,
            .source = .builtin,
        };
        try cache.entries.put(hex_slice, resolved);
        return resolved;
    }

    return .{
        .selector = selector,
        .signature = "unknown()",
        .confidence = 0.0,
        .source = .unknown,
    };
}

fn selectorToHex(sel: [4]u8) [10]u8 {
    var result: [10]u8 = .{ '0', 'x', 0, 0, 0, 0, 0, 0, 0, 0 };
    const hex_chars = "0123456789abcdef";
    for (sel, 0..) |b, i| {
        result[2 + i * 2] = hex_chars[b >> 4];
        result[3 + i * 2] = hex_chars[b & 0xf];
    }
    return result;
}

pub fn selectorToSlice(sel: [4]u8) []const u8 {
    var buf: [10]u8 = selectorToHex(sel);
    return &buf;
}

pub fn hexToSelector(hex: []const u8) ?[4]u8 {
    if (hex.len != 10) return null;
    if (!std.mem.startsWith(u8, hex, "0x")) return null;

    var result: [4]u8 = undefined;
    for (0..4) |i| {
        const byte_hex = hex[2 + i * 2 .. 4 + i * 2];
        result[i] = std.fmt.parseInt(u8, byte_hex, 16) catch return null;
    }
    return result;
}
