// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '../interfaces/IUniswap.sol';
import './GameERC20.sol';

contract PlayToEarnERC20 is GameERC20, ReentrancyGuard {
    uint256 public constant maxSupply = 1000 * 10**6 * 1 ether;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool public antiBotEnabled = true;
    uint256 public antiBotDuration = 10 minutes;
    uint256 public antiBotTime = block.timestamp + antiBotDuration;
    uint256 public antiBotAmount = 450000 * 1 ether;
    mapping(address => bool) bots;

    constructor(string memory name, string memory symbol) GameERC20(name, symbol) {
        _mint(_msgSender(), maxSupply - amountFarm - amountPlayToEarn);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        uniswapV2Router = _uniswapV2Router;
        _approve(address(this), address(uniswapV2Router), ~uint256(0));
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function setBots(address _bots) external onlyOwner {
        require(!bots[_bots]);

        bots[_bots] = true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (antiBotTime > block.timestamp && amount > antiBotAmount && bots[sender]) {
            revert('Anti Bot');
        }

        uint256 transferFeeRate = recipient == uniswapV2Pair ? sellFeeRate : (sender == uniswapV2Pair ? buyFeeRate : 0);

        if (transferFeeRate > 0 && sender != address(this) && recipient != address(this)) {
            uint256 _fee = (amount * transferFeeRate) / 100;
            super._transfer(sender, address(this), _fee); // TransferFee
            amount = amount - _fee;
        }

        super._transfer(sender, recipient, amount);
    }

    function sweepTokenForBosses() public nonReentrant {
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= tokenForBosses) {
            swapTokensForEth(tokenForBosses);
        }
    }

    // receive eth from uniswap swap
    receive() external payable {}

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            addressForBosses, // The contract
            block.timestamp
        );
    }

    function setAddressForBosses(address _addressForBosses) external onlyOwner {
        require(_addressForBosses != address(0), '0x is not accepted here');

        addressForBosses = _addressForBosses;
    }

    function antiBot(uint256 amount) external onlyOwner {
        require(amount > 0, 'not accept 0 value');

        antiBotAmount = amount;
        antiBotEnabled = true;
        antiBotTime = block.timestamp + antiBotDuration;
    }

    function unfreezeBot() external onlyOwner {
        antiBotAmount = 0;
        antiBotEnabled = false;
        antiBotTime = 0;
    }
}
