using System;
using System.Threading.Tasks;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.Extensibility;
using System.Collections.Generic;

namespace web
{
    public class ApplicationInsightsService
    {
        private TelemetryClient client;
        public ApplicationInsightsService(string instrumentationKey)
        {
            client = new TelemetryClient();
            client.InstrumentationKey = instrumentationKey;
        }
        public async Task StoreEvent(string logs) {
            Console.WriteLine(logs);
            client.TrackEvent("TelemetryReceived", new Dictionary<string, string>
            {
                { "Telemetry", logs }
            });
        }
    }
}