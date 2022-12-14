// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {CFAv1Forwarder} from "protocol-monorepo/packages/ethereum-contracts/contracts/utils/CFAv1Forwarder.sol";
import {ISuperfluid, ISuperApp, ISuperToken} from "protocol-monorepo/packages/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperAppDefinitions} from "protocol-monorepo/packages/ethereum-contracts/contracts/interfaces/superfluid/Definitions.sol";
import {IConstantFlowAgreementV1} from "protocol-monorepo/packages/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {SimpleStreamManager} from "./SimpleStreamManager.sol";

import "forge-std/console.sol";

contract SimpleStreamManagerFactory is Ownable {
    error ZeroAddress();
    error InvalidName();
    error InvalidPaymentFlowrate(int96 paymentFlowrate);


    event NewManagerCreated(
        address indexed creator,
        address streamManager,
        string name,
        string symbol,
        address paymentSuperToken,
        int96 paymentFlowrate
    );
    event ManagerImplementationChanged(
        address newStreamManagerImplementation,
        address oldStreamManagerImplementation
    );


    address public immutable FORWARDER;
    address public streamManagerImplementation;

    uint256 private constant CONFIG_WORD =
        SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP |
            SuperAppDefinitions.APP_LEVEL_FINAL;


    constructor(
        address _cfaV1Forwarder,
        address _streamManagerImplementation
    ) {
        if (
            _cfaV1Forwarder == address(0) ||
            _streamManagerImplementation == address(0)
        ) revert ZeroAddress();

        FORWARDER = _cfaV1Forwarder;
        streamManagerImplementation = _streamManagerImplementation;
    }

    function initStreamManager(
        string calldata _name,
        string calldata _symbol,
        address _paymentToken,
        int96 _paymentFlowrate
    ) external returns (address _newStreamManager) {
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_paymentFlowrate < 0)
            revert InvalidPaymentFlowrate(_paymentFlowrate);
        if (bytes(_name).length == 0) revert InvalidName();

        _newStreamManager = Clones.clone(streamManagerImplementation);

        SimpleStreamManager(_newStreamManager).initialize(
            _name,
            _symbol,
            msg.sender,
            _paymentToken,
            FORWARDER,
            _paymentFlowrate
        );

        emit NewManagerCreated(
            msg.sender,
            _newStreamManager,
            _name,
            _symbol,
            _paymentToken,
            _paymentFlowrate
        );
    }

    function setManagerImplementation(address _newStreamManagerImplementation)
        external
        onlyOwner
    {
        if (_newStreamManagerImplementation == address(0)) revert ZeroAddress();

        address oldImplementation = streamManagerImplementation;
        streamManagerImplementation = _newStreamManagerImplementation;

        emit ManagerImplementationChanged(
            _newStreamManagerImplementation,
            oldImplementation
        );
    }
}
