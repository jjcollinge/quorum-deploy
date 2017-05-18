using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using System.Collections.Generic;
using Nethereum.Contracts;

namespace web
{
    class Program
    {
        public static EthereumService ethereum;
        public static ApplicationInsightsService appInsights;
        static async Task StoreEvent(List<EventLog<TelemetryEvent>> log)
        {
            Console.WriteLine("Storing event");
            var json = JsonConvert.SerializeObject(log);
            await appInsights.StoreEvent(json);
        }
        static async Task<decimal> GetBalance(string walletAddress)
        {
            Console.WriteLine("Getting balance");
            return await ethereum.GetBalance(walletAddress);
        }
        static void Main(string[] args)
        {
            Task t = MainAsync();
            t.Wait();
        }
        static async Task MainAsync()
        {
            var builder = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .AddEnvironmentVariables();
            IConfigurationRoot configuration = builder.Build();
            // Load Ethereum settings
            var ethereumSettings = new EthereumSettings();
            configuration.GetSection("EthereumSettings").Bind(ethereumSettings);
            // Load Contract settings
            var contractSettings = new EthereumContractSettings();
            configuration.GetSection("EthereumContractSettings").Bind(contractSettings);
            // Load ApplicationInsights settings
            var appInsightsSettings = new ApplicationInsightsSettings();
            configuration.GetSection("ApplicationInsights").Bind(appInsightsSettings);

            // Get ethereum balance
            ethereum = new EthereumService(ethereumSettings);
            var balance = await GetBalance(ethereumSettings.EthereumAccount);
            Console.WriteLine($"Balance: {balance}");

            // Initialise Application Insights
            appInsights = new ApplicationInsightsService(appInsightsSettings.InstrumentationKey);
            var contract = ethereum.GetContract(contractSettings.Abi, contractSettings.Address);
            var evt = contract.GetEvent("TelemetryReceived");
            var filterAll = await evt.CreateFilterAsync();

            while (true)
            {
                var logs = await evt.GetFilterChanges<TelemetryEvent>(filterAll);
                if (logs.Count > 0)
                    await StoreEvent(logs);
                await Task.Delay(5000);
            }
        }
    }
}
