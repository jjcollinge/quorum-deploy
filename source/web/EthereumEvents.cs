using Nethereum.ABI.FunctionEncoding.Attributes;

namespace web {
    public class TelemetryEvent
    {
        [Parameter("address", "from", 1, true)]
        public string From {get; set;}

        [Parameter("string", "telemetry", 2, true)]
        public string Telemetry {get; set;}
    }
}
