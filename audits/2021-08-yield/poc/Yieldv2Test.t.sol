// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "contracts/interfaces/external/IERC20.sol";
import {ERC20} from "contracts/utils/token/ERC20.sol";
import {ERC20Rewards} from "contracts/utils/token/ERC20Rewards.sol";
import {Strategy, ILadle} from "contracts/yieldspace/Strategy.sol";
import {Ladle, ICauldron, IWETH9} from "contracts/Ladle.sol";
import {Cauldron} from "contracts/Cauldron.sol";
import {Pool, IPool, IPoolFactory} from "contracts/yieldspace/Pool.sol";
import {FYToken, IOracle, IJoin} from "contracts/FYToken.sol";
import {ChainlinkMultiOracle} from "contracts/oracles/chainlink/ChainlinkMultiOracle.sol";
import {AggregatorV3Interface} from "contracts/oracles/chainlink/AggregatorV3Interface.sol";
import {Join} from "contracts/Join.sol";
import {PoolFactory} from "contracts/yieldspace/PoolFactory.sol";
import {DataTypes} from "contracts/interfaces/vault/DataTypes.sol";

contract YieldV2Test is Test {
    BaseToken public base;
    StableCoin public stable;
    NonStandardToken public nonStandard;
    RewardsHarness public erc20RewardToken;
    Strategy public strategy;
    Cauldron public cauldron;
    Ladle public ladle;
    WETH9_ public weth;
   
    FYToken public fyToken;
    ChainlinkMultiOracle public oracle;
    MockAggregator public mockAggregator;
    Join public join;
    PoolFactory public poolFactory;

    address public pool;

    uint32 public start = uint32(block.timestamp + 5 minutes);
    uint32 public end = uint32(block.timestamp + 7 days);
    uint96 public rate = 10 wei;
    uint32 public newStart = uint32(block.timestamp + 5 minutes);
    uint32 public newEnd = uint32(block.timestamp + 7 days);
    uint96 public newRate = 1 wei;
    uint32 public maturity = uint32(block.timestamp + 365 days);
    uint32 public ratio = 1e6;

    uint256 public constant AMOUNT = 1000e18;

    uint256 public constant MINIMUM_AMOUNT = 1e18;

    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    bytes6 public baseId; 
    bytes6 public seriesId;
    bytes12 public vaultId;
    bytes6[] public ilkIds;

    function setUp() public {
        base = new BaseToken();

        stable = new StableCoin();

        cauldron = new Cauldron();

        weth = new WETH9_();

        poolFactory = new PoolFactory();

        oracle = new ChainlinkMultiOracle();

        mockAggregator = new MockAggregator();

        join = new Join(address(base));

        fyToken = new FYToken(baseId, IOracle(address(oracle)), IJoin(address(join)), maturity, "FYToken","FYT");

        pool = poolFactory.createPool(address(base), address(fyToken));

        ladle = new Ladle(ICauldron(address(cauldron)), IWETH9(address(weth)));

        baseId = bytes6("BASE");
        seriesId = bytes6("ID");
        vaultId = bytes12("VAULT ID 1");
        ilkIds.push(baseId);

        cauldron.grantRole(cauldron.addAsset.selector, address(this));
        cauldron.grantRole(cauldron.addSeries.selector, address(this));
        cauldron.grantRole(cauldron.setRateOracle.selector, address(this));
        cauldron.grantRole(cauldron.build.selector, address(this));
        cauldron.grantRole(cauldron.setSpotOracle.selector, address(this));
        cauldron.grantRole(cauldron.addIlks.selector, address(this));

        cauldron.grantRole(cauldron.build.selector, address(ladle));
        cauldron.grantRole(cauldron.pour.selector, address(ladle));
        cauldron.grantRole(cauldron.destroy.selector, address(ladle));

        // The Ladle pulls collateral in and pushes it out during pour/close.
        join.grantRole(join.join.selector, address(ladle));
        join.grantRole(join.exit.selector, address(ladle));

        // The Ladle mints fyToken when the strategy borrows, and burns it when it repays.
        fyToken.grantRole(fyToken.mint.selector, address(ladle));
        fyToken.grantRole(fyToken.burn.selector, address(ladle));

        // Test contract mints fyToken for pool seeding and configures oracle sources.
        fyToken.grantRole(fyToken.mint.selector, address(this));
        oracle.grantRole(oracle.setSource.selector, address(this));

        cauldron.addAsset(baseId, address(base));
        cauldron.setRateOracle(baseId, IOracle(address(oracle)));
        cauldron.addSeries(seriesId, baseId, fyToken);
        cauldron.setSpotOracle(baseId, baseId, IOracle(address(oracle)), ratio);
        cauldron.addIlks(seriesId, ilkIds);

        // startPool borrows fyToken against base collateral; the per-pair debt ceiling defaults to zero.
        cauldron.grantRole(cauldron.setDebtLimits.selector, address(this));
        cauldron.setDebtLimits(baseId, baseId, 1e6, 0, 18);

        // The borrow-time collateralization check hits (base -> base); the post-maturity
        // accrual hits (base -> "rate"). setSource registers both directions.
        oracle.setSource(baseId, baseId, address(mockAggregator));
        oracle.setSource(baseId, bytes6("rate"), address(mockAggregator));

        ladle.grantRole(ladle.addJoin.selector, address(this));
        ladle.addJoin(baseId, IJoin(address(join)));

        strategy = new Strategy("Strategy LiquidityPool Token", "SLP", 18, ILadle(address(ladle)), IERC20(address(base)), baseId);

        strategy.grantRole(strategy.setNextPool.selector, address(this));
        strategy.grantRole(strategy.endPool.selector, address(this));

        strategy.setNextPool(IPool(address(pool)), seriesId);

        nonStandard = new NonStandardToken();

        erc20RewardToken = new RewardsHarness();
        erc20RewardToken.grantRole(ERC20Rewards.setRewards.selector, address(this));
        erc20RewardToken.setRewards(IERC20(address(base)), start, end, rate);
        base.mint(address(erc20RewardToken), uint256(end - start) * uint256(rate));
        base.mint(address(strategy), AMOUNT);
        base.mint(pool, AMOUNT);

        // Seed the pool. A fresh pool initializes from base only ("Pool: Initialize only from base"),
        // so initialize it with the base already sitting in it, then trade fyToken for base
        // to give the pool two-sided reserves for startPool's proportional split.
        IPool(address(pool)).mint(address(this), true, 0);

        fyToken.mint(user, 10e18);
        vm.startPrank(user);
        // buyBase takes its payment from fyToken already sitting unaccounted in the pool.
        fyToken.transfer(pool, 2e18);
        // Route the bought base to user3 so reward tests see user starting from zero base.
        IPool(address(pool)).buyBase(user3, uint128(1e18), uint128(10e18));
        vm.stopPrank();
    }
    function testFirstMinterReceivesPastRewards() public {
        vm.warp(uint256(start) + 1 days);

        vm.prank(user);
        erc20RewardToken.mint(user, 1 ether);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(user);
        uint256 claimed = erc20RewardToken.claim(user);

        uint256 legitimateRewards = 2 hours * uint256(rate);
        uint256 incorrectlyClaimed = (1 days + 2 hours) * uint256(rate);

        assertEq(claimed, incorrectlyClaimed);
        assertGt(claimed, legitimateRewards);
        assertEq(base.balanceOf(user), claimed);
    }

    function testUnderFundedNewToken_CausesDOS() public {
        vm.warp(uint256(start) + 1 days);

        vm.prank(user);
        erc20RewardToken.mint(user, 1 ether);

        vm.warp(block.timestamp + 10 hours);

        vm.prank(user);
        erc20RewardToken.claim(user);

        // User 2 mint. 
        vm.prank(user2);
        erc20RewardToken.mint(user2, 1 ether);

        vm.warp(block.timestamp + 8 days);

        vm.prank(user2);
        erc20RewardToken.transfer(user3, 0);

        (uint128 oldAccrued, ) = erc20RewardToken.rewards(user2);
        console.log("Old Accrued:", oldAccrued);

        uint32 latestStart = uint32(block.timestamp + 5 minutes);
        uint32 latestEnd = uint32(block.timestamp + 7 days);
    
        // New reward token set. 
        erc20RewardToken.setRewards(IERC20(address(stable)), latestStart, latestEnd, newRate);
        stable.mint(address(erc20RewardToken), uint256(latestEnd - latestStart) * uint256(newRate));

        // User2 claim reverts
        vm.expectRevert("ERC20: Insufficient balance"); 
        vm.prank(user2);
        erc20RewardToken.claim(user2); 

        assertGt(oldAccrued, 0);
        assertEq(base.balanceOf(user2), 0); 
    }

    function testAdequatelyFundedNewTokensRewardsUsers_LowerThanOldAccumulated() public {
        vm.warp(uint256(start) + 1 days);

        vm.prank(user);
        erc20RewardToken.mint(user, 1 ether);

        vm.warp(block.timestamp + 10 hours);

        vm.prank(user);
        erc20RewardToken.claim(user);

        // User 2 mint. 
        vm.prank(user2);
        erc20RewardToken.mint(user2, 1 ether);

        vm.warp(block.timestamp + 8 days);

        vm.prank(user2);
        erc20RewardToken.transfer(user3, 0);

        (uint128 oldAccrued, ) = erc20RewardToken.rewards(user2);
        console.log("Old Accrued:", oldAccrued);

        uint32 latestStart = uint32(block.timestamp + 5 minutes);
        uint32 latestEnd = uint32(block.timestamp + 7 days);
    
        // New reward token set. 
        erc20RewardToken.setRewards(IERC20(address(stable)), latestStart, latestEnd, newRate);
        stable.mint(address(erc20RewardToken), oldAccrued + uint256(latestEnd - latestStart) * uint256(newRate));

        // User2 claim
        vm.prank(user2);
        uint256 claimed = erc20RewardToken.claim(user2); 

        console.log("User2 Claimed:", claimed);
        console.log("User2 Stable Balance:", stable.balanceOf(user2));
        console.log("User2 BaseToken Balance:", base.balanceOf(user2));

        assertEq(stable.balanceOf(user2), oldAccrued, "User2 receives new tokens in 6 decimals whereas old accumulated rewards are in 18 decimals");
        assertEq(base.balanceOf(user2), 0); 
    }

    function testRepeatedTransfersCanEraseRewardIntervals() public {
        vm.warp(uint256(start));

        vm.prank(user);
        erc20RewardToken.mint(user, 10 ether);

        vm.prank(user2);
        erc20RewardToken.mint(user2, 10 ether);

        vm.warp(block.timestamp + 1 seconds);
        vm.startPrank(user);
        console.log("User1 Balance:", erc20RewardToken.balanceOf(user));
        erc20RewardToken.transfer(user3, 0);
        vm.stopPrank();

        for(uint256 i; i < 100; i++) {
            (uint128 accumulated, uint32 lastUpdated,) = erc20RewardToken.rewardsPerToken();
            assertEq(lastUpdated, block.timestamp);
            vm.warp(block.timestamp + 1 seconds);
            assertEq(accumulated, 0);

            vm.prank(user);
            erc20RewardToken.transfer(user3, 0);
        }
        vm.prank(user);
        uint256 claimed = erc20RewardToken.claim(user);

        assertEq(claimed, 0);
    }

    function testFalseReturningRewardTokenSilentlyLosesRewards() public {
        erc20RewardToken.setRewards(IERC20(address(nonStandard)), start, end, rate);
        nonStandard.mint(address(erc20RewardToken), uint256(end - start) * uint256(rate));

        vm.warp(uint256(start));

        vm.prank(user);
        erc20RewardToken.mint(user, 10 ether);

        vm.warp(block.timestamp + 8 days);

        uint256 supplyBefore = nonStandard.totalSupply();

        vm.prank(user);
        uint256 claimed = erc20RewardToken.claim(user);

        (uint128 accumulated, ) = erc20RewardToken.rewards(user);

        assertGt(claimed, 0);
        assertEq(accumulated, 0);

        // User received no reward after claiming. 
        assertEq(nonStandard.balanceOf(user), 0);
        assertEq(nonStandard.totalSupply(), supplyBefore);
    }
    // Test to very mint and endPool reverts. 
    function testMintAndEndPool_RevertsWhenAllSharesAreBurned() public {
        vm.prank(user);
        strategy.startPool();
        assertGt(strategy.cached(), 0);
        assertEq(strategy.cached(), strategy.balanceOf(user));

        vm.startPrank(user);
        strategy.transfer(address(strategy), strategy.balanceOf(user));
        strategy.burn(user);
        vm.stopPrank();

        assertEq(strategy.balanceOf(user), 0);
        assertEq(strategy.cached(), 0);
        assertEq(strategy.totalSupply(), 0);

        // Reverts due to division by zero: minted = _totalSupply * deposit / cached.
        vm.expectRevert(abi.encodeWithSelector(bytes4(0x4e487b71), uint256(0x12)));
        vm.prank(user2);
        strategy.mint(user);

        vm.warp(maturity + 1 hours);

        // A keeper matures the series first; otherwise debtToBase mutates state inside
        // Strategy view-declared staticcall and reverts before reaching the transfer.
        cauldron.mature(seriesId);

        vm.expectRevert("ERC20: Insufficient balance");
        strategy.endPool();

        // The vault debt is still outstanding and the collateral still locked, forever.
        (uint128 strandedInk, uint128 strandedArt) = cauldron.balances(strategy.vaultId());
        assertGt(strandedArt, 0);
        assertGt(strandedInk, 0);
    }

    // Test to verify direct LP Transfer can't restore the Strategy once all minters burns their tokens. 
    function testPoolLPTransferToStrategy_DontRestoreStrategy() public {
        vm.prank(user);
        strategy.startPool();
        assertGt(strategy.cached(), 0);
        assertEq(strategy.cached(), strategy.balanceOf(user));

        vm.startPrank(user);
        strategy.transfer(address(strategy), strategy.balanceOf(user));
        strategy.burn(user);
        vm.stopPrank();

        assertEq(strategy.balanceOf(user), 0);
        assertEq(strategy.cached(), 0);
        assertEq(strategy.totalSupply(), 0);

        IPool(pool).transfer(address(strategy), AMOUNT);

        assertEq(IPool(pool).balanceOf(address(strategy)), AMOUNT);

        // Reverts due to division by zero: minted = _totalSupply * deposit / cached.
        vm.expectRevert(abi.encodeWithSelector(bytes4(0x4e487b71), uint256(0x12)));
        vm.prank(user2);
        strategy.mint(user2);
    }
}

contract MockAggregator is AggregatorV3Interface {
    function decimals() external pure override returns (uint8) {
        return 8;
    }

    function description() external pure override returns (string memory) {
        return "Mock price feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external view override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return _latest();
    }

    function latestRoundData()
        external view override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return _latest();
    }

    // _peek requires: rawPrice > 0, updatedAt != 0, answeredInRound >= roundId.
    // decimals 8 with answer 1e8 normalizes to a 1:1 price (1e18), forwards and inverse.
    function _latest()
        internal view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, 1e8, 1, block.timestamp, 1);
    }
}

contract BaseToken is ERC20 {
    constructor() ERC20("Base", "BASE", 18) {}
    function mint(address dst, uint wad) external virtual returns (bool) {
     return _mint(dst, wad);
    }
}

contract NonStandardToken is ERC20 {
    constructor() ERC20("NonStandardToken", "NST", 18) {}
    function mint(address dst, uint wad) external virtual returns (bool) {
     return _mint(dst, wad);
    }
    function transfer(address /*dst*/, uint /*wad*/) external virtual override returns (bool) {
        return false;
    }
}

contract StableCoin is ERC20 {
    constructor() ERC20("Base", "BASE", 6) {}
    function mint(address dst, uint wad) external virtual returns (bool) {
     return _mint(dst, wad);
    }
}

contract RewardsHarness is ERC20Rewards {
    constructor() ERC20Rewards("Reward Shares", "RSH", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(address dst, uint wad) external virtual override returns (bool) {
        return _transfer(msg.sender, dst, wad);
    }
}

contract WETH9_ {
    string public name     = "Wrapped Ether";
    string public symbol   = "WETH";
    uint8  public decimals = 18;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    receive() external payable {
        deposit();
    }
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != 0) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}