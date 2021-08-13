//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '../libraries/SafeMath.sol';

contract Membership is Ownable {
    using SafeMath for uint256;
    enum MemberType {
        VIP1,
        VIP7,
        VIPX
    }
    /* member address => expiry time */
    mapping(address => uint256) public memberTimeMap;
    /* member address => member type */
    mapping(address => MemberType) public memberTypeMap;
    /* member type => member fee */
    mapping(MemberType => uint256) public memberFeeMap;

    uint256 public referralRate = 5; // 5%
    uint256 public totalMember = 0;

    constructor() public {
        setMemberFees(1 ether, 5 ether, 30 ether);
    }

    function updateReferralRate(uint256 _referralRate) external onlyOwner {
        require(_referralRate <= 100, 'Invaild referral rate');
        referralRate = _referralRate;
    }

    function premium(
        address user,
        uint256 memberType,
        address referral
    ) payable public {
        require(memberType < 3, 'Invalid member type');
        require(msg.value >= memberFeeMap[MemberType(memberType)], 'Insufficient member fee');

        if (memberTimeMap[user] == 0) {
            memberTimeMap[user] = block.timestamp;
        }

        if (memberType == uint(MemberType.VIP1)) {
            memberTimeMap[user] += 1 days;
        } else if (memberType == uint(MemberType.VIP7)) {
            memberTimeMap[user] += 1 weeks;
        } else {
            memberTimeMap[user] += 10000 * 365 days;
        }

        memberTypeMap[user] = MemberType(memberType) ;

        uint256 fee = msg.value;
        if (referral != address(0x0) && referral != owner() && referral != user) {
            uint256 referralFee = fee.mul(referralRate) / 100;
            payable(referral).transfer(referralFee);
            fee = fee.sub(referralFee);
        }

        payable(owner()).transfer(fee);
        totalMember += 1;
    }

    function isMember(address user) external view returns (bool) {
        return memberTimeMap[user] > now;
    }

    function setMemberFees(
        uint256 fee1,
        uint256 fee7,
        uint256 feeX
    ) public onlyOwner {
        memberFeeMap[MemberType.VIP1] = fee1;
        memberFeeMap[MemberType.VIP7] = fee7;
        memberFeeMap[MemberType.VIPX] = feeX;
    }
}
