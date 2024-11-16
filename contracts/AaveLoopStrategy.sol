// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint wad) external;
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
}
contract AaveLoopStrategy {
    using SafeERC20 for IERC20;

    // Base Sepolia addresses
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address public constant POOL_ADDRESSES_PROVIDER = 0xd449FeD49d9C443688d6816fE6872F21402e41de;
    address public constant UNISWAP_ROUTER = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;
    uint24 public constant POOL_FEE = 3000; // 0.3% fee tier

    IPool public immutable lendingPool;
    ISwapRouter public immutable swapRouter;
    IWETH9 public immutable weth;
    uint256 public constant SAFETY_FACTOR = 80;
    uint256 public constant SLIPPAGE = 50; // 0.5%
// Add new event for failures
event LoopFailed(uint256 loopNumber, string reason);
    constructor() {
        IPoolAddressesProvider provider = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
        lendingPool = IPool(provider.getPool());
        swapRouter = ISwapRouter(UNISWAP_ROUTER);
        weth = IWETH9(WETH);
    }

    receive() external payable {}

function executeLoop(
    uint256 borrowAmount,
    uint256 numLoops
) external payable {
    require(numLoops > 0 && numLoops <= 5, "Invalid number of loops");
    require(msg.value > 0, "Must provide ETH");

    // Wrap ETH to WETH
    weth.deposit{value: msg.value}();

    // Approve tokens
    IERC20(WETH).approve(address(lendingPool), type(uint256).max);
    IERC20(USDC).approve(address(lendingPool), type(uint256).max);
    IERC20(USDC).approve(UNISWAP_ROUTER, type(uint256).max);

    // Initial deposit of WETH
    lendingPool.supply(WETH, msg.value, address(this), 0);

    for(uint256 i = 0; i < numLoops; i++) {
        (
            uint256 totalCollateral,
            uint256 totalDebt,
            uint256 availableBorrows,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = lendingPool.getUserAccountData(address(this));

        require(healthFactor >= 1.05e18, "Health factor too low");

        // More conservative borrowing - use 50% of available borrows

        // Add minimum borrow check
        require(borrowAmount >= 1e6, "Borrow amount too small");

        if(borrowAmount > 0) {
try lendingPool.borrow(
            USDC,
            borrowAmount,
            2, // Variable interest rate
            0, // Referral code
            address(this)
            ) {
                // 2. Swap USDC to WETH using Uniswap
                ISwapRouter.ExactInputSingleParams memory params =
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: USDC,
                        tokenOut: WETH,
                        fee: POOL_FEE,
                        recipient: address(this),
                        deadline: block.timestamp + 300,
                        amountIn: borrowAmount,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    });

                uint256 amountOut = swapRouter.exactInputSingle(params);

                // 3. Supply swapped WETH back to Aave
                lendingPool.supply(WETH, amountOut, address(this), 0);

                emit LoopExecuted(i + 1, borrowAmount, amountOut);
            } catch Error(string memory reason) {
                emit LoopFailed(i + 1, reason);
                break; // Exit the loop if borrowing fails
            }
        } else {
            break; // Exit if borrow amount is 0
        }
    }
}

    function emergencyExit() external {
        (
            uint256 totalCollateral,
            uint256 totalDebt,
            ,,,
        ) = lendingPool.getUserAccountData(address(this));

        if (totalDebt > 0) {
            // Repay USDC debt
            lendingPool.repay(USDC, totalDebt, 2, address(this));
        }

        if (totalCollateral > 0) {
            // Withdraw WETH
            lendingPool.withdraw(WETH, type(uint256).max, address(this));
        }

        // Unwrap WETH to ETH
        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        if (wethBalance > 0) {
            weth.withdraw(wethBalance);
            // Transfer ETH back to caller
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "ETH transfer failed");
        }

        // Transfer any remaining USDC to caller
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
        if (usdcBalance > 0) {
            IERC20(USDC).safeTransfer(msg.sender, usdcBalance);
        }

        emit EmergencyExitExecuted(totalCollateral, totalDebt);
    }

    function getPosition() external view returns (
        uint256 totalCollateral,
        uint256 totalDebt,
        uint256 availableBorrows,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ) {
        return lendingPool.getUserAccountData(address(this));
    }

    // Events
    event LoopExecuted(uint256 loopNumber, uint256 borrowedAmount, uint256 swappedAmount);
    event EmergencyExitExecuted(uint256 totalCollateral, uint256 totalDebt);
}
