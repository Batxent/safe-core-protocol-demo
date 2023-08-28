// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ISafe} from "@safe-global/safe-core-protocol/contracts/interfaces/Accounts.sol";
import {ISafeProtocolManager} from "@safe-global/safe-core-protocol/contracts/interfaces/Manager.sol";
import {SafeTransaction} from "@safe-global/safe-core-protocol/contracts/DataTypes.sol";
import {BasePluginWithStoredMetadata, PluginMetadata} from "./Base.sol";

interface ISocial {
    event Follow(address indexed follower, address indexed following);
    event Unfollow(address indexed follower, address indexed following);
    event BlockUser(address indexed blocker, address indexed blocked);
    event UnblockUser(address indexed blocker, address indexed blocked);
    event PermissionChanged(address indexed user, uint32 permission);
    event UserMetadataChanged(address indexed user, bytes32 metadata);

    function follow(address _follower, address _following) external returns (bool);

    function unfollow(address _follower, address _following) external returns (bool);

    function isFollowing(address _follower, address _following) external view returns (bool);

    function followingList(address _follower) external view returns (address[] memory);

    function followerList(address _following) external view returns (address[] memory);

    function blockUser(address _blocker, address _blocked) external returns (bool);

    function unblockUser(address _blocker, address _blocked) external returns (bool);

    function isBlocked(address _blocker, address _blocked) external view returns (bool);

    function blockedList(address _blocker) external view returns (address[] memory);

    function setPermission(address _user, uint32 _permission) external returns (bool);

    function getPermission(address _user) external view returns (uint32);

    function setMetadata(address _user, bytes32 _metadata) external returns (bool);

    function getMetadata(address _user) external view returns (bytes32);

    function canChat(address _sender, address _receiver) external view returns (bool);
}

contract SocialPlugin is ISocial, BasePluginWithStoredMetadata {
    struct User {
        address id;
        uint32 permission;
        bytes32 metadata;
        mapping(address => bool) following;
        mapping(address => bool) followers;
        mapping(address => bool) blocked;
        address[] followingList;
        address[] followerList;
        address[] blockedList;
    }

    mapping(address => User) private users;

    modifier onlyUser(address _user) {
        require(msg.sender == _user, "Caller is not the specified user");
        _;
    }

    constructor()
        BasePluginWithStoredMetadata(
            PluginMetadata({name: "Soical Plugin", version: "0.1.0", requiresRootAccess: false, iconUrl: "", appUrl: ""})
        )
    {}

    function executeFromPlugin(
        ISafeProtocolManager manager,
        ISafe safe,
        SafeTransaction calldata safetx
    ) external returns (bytes[] memory data) {
        (data) = manager.executeTransaction(safe, safetx);
    }

    function follow(address _follower, address _following) external override onlyUser(_follower) returns (bool) {
        require(_follower != _following, "Cannot follow yourself");
        require(!users[_follower].blocked[_following], "You have blocked this user");

        users[_follower].following[_following] = true;
        users[_following].followers[_follower] = true;
        users[_follower].followingList.push(_following);
        users[_following].followerList.push(_follower);

        emit Follow(_follower, _following);
        return true;
    }

    function unfollow(address _follower, address _following) external override onlyUser(_follower) returns (bool) {
        require(users[_follower].following[_following], "You are not following this user");

        users[_follower].following[_following] = false;
        users[_following].followers[_follower] = false;
        removeAddressFromArray(users[_follower].followingList, _following);
        removeAddressFromArray(users[_following].followerList, _follower);

        emit Unfollow(_follower, _following);
        return true;
    }

    function isFollowing(address _follower, address _following) external view override returns (bool) {
        return users[_follower].following[_following];
    }

    function blockUser(address _blocker, address _blocked) external override onlyUser(_blocker) returns (bool) {
        require(_blocker != _blocked, "Cannot block yourself");

        users[_blocker].blocked[_blocked] = true;
        users[_blocker].blockedList.push(_blocked);

        emit BlockUser(_blocker, _blocked);
        return true;
    }

    function unblockUser(address _blocker, address _blocked) external override onlyUser(_blocker) returns (bool) {
        require(users[_blocker].blocked[_blocked], "User is not blocked");

        users[_blocker].blocked[_blocked] = false;
        removeAddressFromArray(users[_blocker].blockedList, _blocked);

        emit UnblockUser(_blocker, _blocked);
        return true;
    }

    function isBlocked(address _blocker, address _blocked) external view override onlyUser(_blocker) returns (bool) {
        return users[_blocker].blocked[_blocked];
    }

    function setPermission(address _user, uint32 _permission) external override onlyUser(_user) returns (bool) {
        users[_user].permission = _permission;

        emit PermissionChanged(_user, _permission);
        return true;
    }

    function getPermission(address _user) external view override returns (uint32) {
        return users[_user].permission;
    }

    function setMetadata(address _user, bytes32 _metadata) external override onlyUser(_user) returns (bool) {
        users[_user].metadata = _metadata;

        emit UserMetadataChanged(_user, _metadata);
        return true;
    }

    function getMetadata(address _user) external view override returns (bytes32) {
        return users[_user].metadata;
    }

    function followingList(address _follower) external view override returns (address[] memory) {
        return users[_follower].followingList;
    }

    function followerList(address _following) external view override returns (address[] memory) {
        return users[_following].followerList;
    }

    function blockedList(address _blocker) external view override onlyUser(_blocker) returns (address[] memory) {
        return users[_blocker].blockedList;
    }

    function canChat(address _sender, address _receiver) external view override returns (bool) {
        uint32 receiverPermission = users[_receiver].permission;
        uint32 chatPermission = receiverPermission & 0x3;
        if (chatPermission == 0x0) {
            return true;
        } else if (chatPermission == 0x1) {
            return users[_receiver].followers[_sender];
        } else if (chatPermission == 0x2) {
            return users[_sender].followers[_receiver];
        } else if (chatPermission == 0x3) {
            return users[_receiver].followers[_sender] && users[_sender].followers[_receiver];
        }
        return false;
    }

    function removeAddressFromArray(address[] storage array, address toRemove) private {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == toRemove) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }
}
