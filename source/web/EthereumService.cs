using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Auth;
using Microsoft.WindowsAzure.Storage.Table;
using Nethereum.Web3;
using System;
using System.Threading.Tasks;
using Nethereum.Contracts;
using System.Collections.Generic;

namespace web
{
    public class EthereumService
    {
        private Nethereum.Web3.Web3 _web3;
        private string _accountAddress;
        private string _password;
        private string _storageKey;
        private string _storageAccount;

        public string AccountAddress
        {
            get { return _accountAddress; }
            set { _accountAddress = value; }
        }
        public EthereumService(EthereumSettings config)
        {
            _web3 = new Web3(config.EthereumRpcEndpoint);
            _accountAddress = config.EthereumAccount;
            _password = config.EthereumPassword;
            _storageAccount = config.StorageAccount;
            _storageKey = config.StorageKey;
        }
        public Contract GetContract(string abi, string address)
        {
            var contract = _web3.Eth.GetContract(abi, address);
            if(contract == null)
            {
                throw new ArgumentException("The contract does not exists");
            }
            if(contract.Address == null)
            {
                throw new ArgumentException("The contract exists but doesn't have an address");
            }
            return contract;
        }
        public async Task<decimal> GetBalance(string address)
        {
            var balance = await _web3.Eth.GetBalance.SendRequestAsync(address);
            return _web3.Convert.FromWei(balance.Value, 18);
        }
    }
}