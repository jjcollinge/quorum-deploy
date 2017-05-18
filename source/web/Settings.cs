namespace web
{
    public class EthereumSettings
    {
        public string EthereumAccount { get; set; }
        public string EthereumPassword { get; set; }
        public string EthereumRpcEndpoint { get; set; }
        public string StorageKey { get; set; }
        public string StorageAccount { get; set; }
    }

    public class EthereumContractSettings
    {
        public string Abi { get; set; }
        public string Address { get; set; }
        public string Name { get; set; }
    }

    public class ApplicationInsightsSettings
    {
        public string InstrumentationKey { get; set; }
    }
}