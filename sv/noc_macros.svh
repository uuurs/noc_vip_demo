// noc_macros.svh - Shared macros for NOC Verification Access Library
`ifndef NOC_MACROS_SVH
`define NOC_MACROS_SVH

// Protocol type enum - shared across all components
`define NOC_PROTOCOL_AXI4       0
`define NOC_PROTOCOL_AXILITE    1
`define NOC_PROTOCOL_AHBLITE    2
`define NOC_PROTOCOL_APB4       3
`define NOC_PROTOCOL_AVALON_MM  4

// Direction
`define NOC_DIR_READ   0
`define NOC_DIR_WRITE  1

// Burst type
`define NOC_BURST_FIXED  0
`define NOC_BURST_INCR   1
`define NOC_BURST_WRAP   2

// Response codes
`define NOC_RESP_OKAY    0
`define NOC_RESP_EXOKAY  1
`define NOC_RESP_SLVERR  2
`define NOC_RESP_DECERR  3

// Error injection types
`define NOC_ERR_ILLEGAL_ADDR      0
`define NOC_ERR_ILLEGAL_BURST     1
`define NOC_ERR_TIMEOUT           2
`define NOC_ERR_DECERR            3
`define NOC_ERR_SLVERR            4
`define NOC_ERR_BOUNDARY_VIOLATION 5

// Backdoor access types
`define NOC_BACKDOOR_RAL   0
`define NOC_BACKDOOR_HDL   1
`define NOC_BACKDOOR_MEM   2

// Severity levels for violation reports
`define NOC_SEVERITY_INFO    0
`define NOC_SEVERITY_WARNING 1
`define NOC_SEVERITY_ERROR   2
`define NOC_SEVERITY_FATAL   3

// Maximum configurable limits
`define NOC_MAX_MASTERS   16
`define NOC_MAX_SLAVES    64
`define NOC_MAX_ADDR_WIDTH 64
`define NOC_MAX_DATA_WIDTH 1024
`define NOC_MAX_ID_WIDTH   16
`define NOC_MAX_OUTSTANDING 256

// Logger output formats
`define NOC_LOG_FMT_CSV  0
`define NOC_LOG_FMT_JSON 1
`define NOC_LOG_FMT_BOTH 2

// Protocol checker rule categories
`define NOC_RULE_HANDSHAKE    "HANDSHAKE"
`define NOC_RULE_DATA_INTEG   "DATA_INTEGRITY"
`define NOC_RULE_BOUNDARY     "BOUNDARY"
`define NOC_RULE_ORDERING     "ORDERING"
`define NOC_RULE_TIMEOUT      "TIMEOUT"
`define NOC_RULE_ALIGNMENT    "ALIGNMENT"
`define NOC_RULE_BURST        "BURST"

// Helper: convert bit vector to string for reports
`define noc_bit2str(val) $sformatf("0x%0h", val)

// Helper: assertion-like check with report
`define NOC_CHECK(cond, rule, detail, addr) \
    if (!(cond)) report_violation(rule, detail, addr, 0)

`endif // NOC_MACROS_SVH
