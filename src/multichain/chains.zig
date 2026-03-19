// Multi-chain Support Module
// Support for EVM-compatible chains beyond Ethereum

const std = @import("std");

pub const Chain = enum(u32) {
    ethereum = 1,
    goerli = 5,
    sepolia = 11155111,
    polygon = 137,
    polygon_mumbai = 80001,
    bsc = 56,
    bsc_testnet = 97,
    avalanche = 43114,
    avalanche_fuji = 43113,
    arbitrum_one = 42161,
    arbitrum_sepolia = 421614,
    optimism = 10,
    optimism_sepolia = 11155420,
    base = 8453,
    base_sepolia = 84532,
    zksync_era = 324,
    zksync_era_testnet = 280,
    gnosis = 100,
    celo = 42220,
    aurora = 1313161554,
    // Add more chains as needed
    unknown = 0,
};

pub const ChainConfig = struct {
    name: []const u8,
    chain_id: u32,
    rpc_url: ?[]const u8,
    explorer_url: ?[]const u8,
    explorer_api_url: ?[]const u8,
    supports_eip_1559: bool,
    supports_eip_3865: bool, // PUSH0 opcode
};

/// Get chain configuration
pub fn getChainConfig(chain: Chain) ChainConfig {
    return switch (chain) {
        .ethereum => .{
            .name = "Ethereum",
            .chain_id = 1,
            .rpc_url = "https://eth.llamarpc.com",
            .explorer_url = "https://etherscan.io",
            .explorer_api_url = "https://api.etherscan.io/api",
            .supports_eip_1559 = true,
            .supports_eip_3865 = true,
        },
        .polygon => .{
            .name = "Polygon",
            .chain_id = 137,
            .rpc_url = "https://polygon-rpc.com",
            .explorer_url = "https://polygonscan.com",
            .explorer_api_url = "https://api.polygonscan.com/api",
            .supports_eip_1559 = true,
            .supports_eip_3865 = true,
        },
        .bsc => .{
            .name = "BNB Smart Chain",
            .chain_id = 56,
            .rpc_url = "https://bsc-dataseed.binance.org",
            .explorer_url = "https://bscscan.com",
            .explorer_api_url = "https://api.bscscan.com/api",
            .supports_eip_1559 = false,
            .supports_eip_3865 = true,
        },
        .avalanche => .{
            .name = "Avalanche",
            .chain_id = 43114,
            .rpc_url = "https://api.avax.network/ext/bc/C/rpc",
            .explorer_url = "https://snowtrace.io",
            .explorer_api_url = "https://api.snowtrace.io/api",
            .supports_eip_1559 = true,
            .supports_eip_3865 = true,
        },
        .arbitrum_one => .{
            .name = "Arbitrum One",
            .chain_id = 42161,
            .rpc_url = "https://arb1.arbitrum.io/rpc",
            .explorer_url = "https://arbiscan.io",
            .explorer_api_url = "https://api.arbiscan.io/api",
            .supports_eip_1559 = true,
            .supports_eip_3865 = true,
        },
        .optimism => .{
            .name = "Optimism",
            .chain_id = 10,
            .rpc_url = "https://mainnet.optimism.io",
            .explorer_url = "https://optimistic.etherscan.io",
            .explorer_api_url = "https://api-optimistic.etherscan.io/api",
            .supports_eip_1559 = true,
            .supports_eip_3865 = true,
        },
        .base => .{
            .name = "Base",
            .chain_id = 8453,
            .rpc_url = "https://mainnet.base.org",
            .explorer_url = "https://basescan.org",
            .explorer_api_url = "https://api.basescan.org/api",
            .supports_eip_1559 = true,
            .supports_eip_3865 = true,
        },
        .zksync_era => .{
            .name = "zkSync Era",
            .chain_id = 324,
            .rpc_url = "https://mainnet.era.zksync.io",
            .explorer_url = "https://explorer.zksync.io",
            .explorer_api_url = "https://block-explorer-api-mainnet.zksync.io",
            .supports_eip_1559 = false,
            .supports_eip_3865 = false, // Different VM
        },
        .gnosis => .{
            .name = "Gnosis Chain",
            .chain_id = 100,
            .rpc_url = "https://rpc.gnosischain.com",
            .explorer_url = "https://gnosisscan.io",
            .explorer_api_url = "https://api.gnosisscan.io/api",
            .supports_eip_1559 = false,
            .supports_eip_3865 = true,
        },
        else => .{
            .name = "Unknown",
            .chain_id = 0,
            .rpc_url = null,
            .explorer_url = null,
            .explorer_api_url = null,
            .supports_eip_1559 = false,
            .supports_eip_3865 = false,
        },
    };
}

/// Get chain from chain ID
pub fn getChainById(chain_id: u32) Chain {
    return switch (chain_id) {
        1 => .ethereum,
        5 => .goerli,
        11155111 => .sepolia,
        137 => .polygon,
        80001 => .polygon_mumbai,
        56 => .bsc,
        97 => .bsc_testnet,
        43114 => .avalanche,
        43113 => .avalanche_fuji,
        42161 => .arbitrum_one,
        421614 => .arbitrum_sepolia,
        10 => .optimism,
        11155420 => .optimism_sepolia,
        8453 => .base,
        84532 => .base_sepolia,
        324 => .zksync_era,
        280 => .zksync_era_testnet,
        100 => .gnosis,
        42220 => .celo,
        1313161554 => .aurora,
        else => .unknown,
    };
}

/// Get all supported chains
pub fn getSupportedChains() []const Chain {
    return &.{
        .ethereum,
        .polygon,
        .bsc,
        .avalanche,
        .arbitrum_one,
        .optimism,
        .base,
        .zksync_era,
        .gnosis,
    };
}

/// Chain precompile addresses (common across EVM chains)
pub const Precompiles = struct {
    /// Ecrecover - ECDSA signature recovery
    pub const ecrecover: u64 = 0x01;
    
    /// SHA256
    pub const sha256: u64 = 0x02;
    
    /// RIPEMD-160
    pub const ripemd160: u64 = 0x03;
    
    /// Identity (copy memory)
    pub const identity: u64 = 0x04;
    
    /// Modexp - modular exponentiation
    pub const modexp: u64 = 0x05;
    
    /// ECADD - elliptic curve addition
    pub const ecadd: u64 = 0x06;
    
    /// ECMUL - elliptic curve multiplication
    pub const ecmul: u64 = 0x07;
    
    /// ECPAIRING - zkSNARK verification
    pub const ecpairing: u64 = 0x08;
    
    /// Blake2F - compression function
    pub const blake2f: u64 = 0x09;
    
    /// Geth's Poseidon hash (some chains)
    pub const poseidon_hash: u64 = 0x0d;
};

/// Check if address is a precompile
pub fn isPrecompile(address: u64) bool {
    // Standard precompiles: 0x01 - 0x09
    if (address >= 0x01 and address <= 0x09) return true;
    
    // Extended precompiles on some chains: 0x0a - 0x0f
    if (address >= 0x0a and address <= 0x0f) return true;
    
    return false;
}

/// Get precompile name
pub fn getPrecompileName(address: u64) ?[]const u8 {
    return switch (address) {
        Precompiles.ecrecover => "ecrecover",
        Precompiles.sha256 => "sha256",
        Precompiles.ripemd160 => "ripemd160",
        Precompiles.identity => "identity",
        Precompiles.modexp => "modexp",
        Precompiles.ecadd => "ecadd",
        Precompiles.ecmul => "ecmul",
        Precompiles.ecpairing => "ecpairing",
        Precompiles.blake2f => "blake2f",
        Precompiles.poseidon_hash => "poseidon_hash",
        else => null,
    };
}
