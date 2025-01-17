// SPDX-License-Identifier: MIT
pragma solidity >=0.4.23 <0.9.0;
pragma experimental ABIEncoderV2;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import { ISetToken } from "@setprotocol/contracts/interfaces/ISetToken.sol";
import { PreciseUnitMath } from "@setprotocol/contracts/lib/PreciseUnitMath.sol";
import { IIssuanceModule } from "@setprotocol/contracts/interfaces/IIssuanceModule.sol";
import { IStreamingFeeModule } from "@setprotocol/contracts/interfaces/IStreamingFeeModule.sol";

import { BaseExtension } from "../lib/BaseExtension.sol";
import { IBaseManager } from "../interfaces/IBaseManager.sol";
import { TimeLockUpgrade } from "../lib/TimeLockUpgrade.sol";


/**
 * @title FeeSplitExtension
 * @author Set Protocol
 *
 * Smart contract extension that allows for splitting and setting streaming and mint/redeem fees.
 */
contract FeeSplitExtension is BaseExtension, TimeLockUpgrade {
    using Address for address;
    using PreciseUnitMath for uint256;
    using SafeMath for uint256;

    /* ============ Events ============ */

    event FeesDistributed(
        address indexed _operatorFeeRecipient,
        address indexed _methodologist,
        uint256 _operatorTake,
        uint256 _methodologistTake
    );

    /* ============ State Variables ============ */

    ISetToken public setToken;
    IStreamingFeeModule public streamingFeeModule;
    IIssuanceModule public issuanceModule;

    // Percent of fees in precise units (10^16 = 1%) sent to operator, rest to methodologist
    uint256 public operatorFeeSplit;

    // Address which receives operator's share of fees when they're distributed. (See IIP-72)
    address public operatorFeeRecipient;

    /* ============ Constructor ============ */

    constructor(
        IBaseManager _manager,
        IStreamingFeeModule _streamingFeeModule,
        IIssuanceModule _issuanceModule,
        uint256 _operatorFeeSplit,
        address _operatorFeeRecipient
    )
        public
        BaseExtension(_manager)
    {
        streamingFeeModule = _streamingFeeModule;
        issuanceModule = _issuanceModule;
        operatorFeeSplit = _operatorFeeSplit;
        operatorFeeRecipient = _operatorFeeRecipient;
        setToken = manager.setToken();
    }

    /* ============ External Functions ============ */

    /**
     * ANYONE CALLABLE: Accrues fees from streaming fee module. Gets resulting balance after fee accrual, calculates fees for
     * operator and methodologist, and sends to operator fee recipient and methodologist respectively. NOTE: mint/redeem fees
     * will automatically be sent to this address so reading the balance of the SetToken in the contract after accrual is
     * sufficient for accounting for all collected fees.
     */
    function accrueFeesAndDistribute() public {
        // Emits a FeeActualized event
        streamingFeeModule.accrueFee(setToken);

        uint256 totalFees = setToken.balanceOf(address(this));

        address methodologist = manager.methodologist();

        uint256 operatorTake = totalFees.preciseMul(operatorFeeSplit);
        uint256 methodologistTake = totalFees.sub(operatorTake);

        if (operatorTake > 0) {
            setToken.transfer(operatorFeeRecipient, operatorTake);
        }

        if (methodologistTake > 0) {
            setToken.transfer(methodologist, methodologistTake);
        }

        emit FeesDistributed(operatorFeeRecipient, methodologist, operatorTake, methodologistTake);
    }

    /**
     * ONLY OPERATOR: Updates streaming fee on StreamingFeeModule.
     * Because the method is timelocked, each party must call it twice: once to set the lock and once to execute.
     *
     * Method is timelocked to protect token owners from sudden changes in fee structure which
     * they would rather not bear. The delay gives them a chance to exit their positions without penalty.
     *
     * NOTE: This will accrue streaming fees though not send to operator fee recipient and methodologist.
     *
     * @param _newFee       Percent of Set accruing to fee extension annually (1% = 1e16, 100% = 1e18)
     */
    function updateStreamingFee(uint256 _newFee)
        external
        onlyOperator
        timeLockUpgrade
    {
        bytes memory callData = abi.encodeWithSignature("updateStreamingFee(address,uint256)", manager.setToken(), _newFee);
        invokeManager(address(streamingFeeModule), callData);
    }

    /**
     * ONLY OPERATOR: Updates issue fee on IssuanceModule. Only is executed once time lock has passed.
     * Because the method is timelocked, each party must call it twice: once to set the lock and once to execute.
     *
     * Method is timelocked to protect token owners from sudden changes in fee structure which
     * they would rather not bear. The delay gives them a chance to exit their positions without penalty.
     *
     * @param _newFee           New issue fee percentage in precise units (1% = 1e16, 100% = 1e18)
     */
    function updateIssueFee(uint256 _newFee)
        external
        onlyOperator
        timeLockUpgrade
    {
        bytes memory callData = abi.encodeWithSignature("updateIssueFee(address,uint256)", manager.setToken(), _newFee);
        invokeManager(address(issuanceModule), callData);
    }

    /**
     * ONLY OPERATOR: Updates redeem fee on IssuanceModule. Only is executed once time lock has passed.
     * Because the method is timelocked, each party must call it twice: once to set the lock and once to execute.
     *
     * Method is timelocked to protect token owners from sudden changes in fee structure which
     * they would rather not bear. The delay gives them a chance to exit their positions without penalty.
     *
     * @param _newFee           New redeem fee percentage in precise units (1% = 1e16, 100% = 1e18)
     */
    function updateRedeemFee(uint256 _newFee)
        external
        onlyOperator
        timeLockUpgrade
    {
        bytes memory callData = abi.encodeWithSignature("updateRedeemFee(address,uint256)", manager.setToken(), _newFee);
        invokeManager(address(issuanceModule), callData);
    }

    /**
     * ONLY OPERATOR: Updates fee recipient on both streaming fee and issuance modules.
     *
     * @param _newFeeRecipient  Address of new fee recipient. This should be the address of the fee extension itself.
     */
    function updateFeeRecipient(address _newFeeRecipient)
        external
        onlyOperator
    {
        bytes memory callData = abi.encodeWithSignature("updateFeeRecipient(address,address)", manager.setToken(), _newFeeRecipient);
        invokeManager(address(streamingFeeModule), callData);
        invokeManager(address(issuanceModule), callData);
    }

    /**
     * ONLY OPERATOR: Updates fee split between operator and methodologist. Split defined in precise units (1% = 10^16).
     *
     * @param _newFeeSplit      Percent of fees in precise units (10^16 = 1%) sent to operator, (rest go to the methodologist).
     */
    function updateFeeSplit(uint256 _newFeeSplit)
        external
        onlyOperator
    {
        require(_newFeeSplit <= PreciseUnitMath.preciseUnit(), "Fee must be less than 100%");
        accrueFeesAndDistribute();
        operatorFeeSplit = _newFeeSplit;
    }

    /**
     * ONLY OPERATOR: Updates the address that receives the operator's fees (see IIP-72)
     *
     * @param _newOperatorFeeRecipient  Address to send operator's fees to.
     */
    function updateOperatorFeeRecipient(address _newOperatorFeeRecipient)
        external
        onlyOperator
    {
        require(_newOperatorFeeRecipient != address(0), "Zero address not valid");
        operatorFeeRecipient = _newOperatorFeeRecipient;
    }
}