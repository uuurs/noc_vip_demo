// noc_violation_report.sv - Protocol violation report object
class noc_violation_report extends uvm_object;

    typedef enum bit [1:0] {
        INFO    = `NOC_SEVERITY_INFO,
        WARNING = `NOC_SEVERITY_WARNING,
        ERROR   = `NOC_SEVERITY_ERROR,
        FATAL   = `NOC_SEVERITY_FATAL
    } severity_e;

    string      protocol;
    string      rule_name;
    string      rule_category;
    string      detail;
    bit [63:0]  address;
    bit [63:0]  data;
    int         master_id;
    int         slave_id;
    realtime    timestamp;
    int         cycle;
    severity_e  severity;

    `uvm_object_utils_begin(noc_violation_report)
        `uvm_field_string(protocol, UVM_DEFAULT)
        `uvm_field_string(rule_name, UVM_DEFAULT)
        `uvm_field_string(rule_category, UVM_DEFAULT)
        `uvm_field_string(detail, UVM_DEFAULT)
        `uvm_field_int(address, UVM_DEFAULT)
        `uvm_field_int(master_id, UVM_DEFAULT)
        `uvm_field_int(slave_id, UVM_DEFAULT)
        `uvm_field_int(timestamp, UVM_DEFAULT)
        `uvm_field_int(cycle, UVM_DEFAULT)
        `uvm_field_enum(severity_e, severity, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "noc_violation_report");
        super.new(name);
        protocol     = "";
        rule_name    = "";
        rule_category = "";
        detail       = "";
        address      = 64'h0;
        data         = 64'h0;
        master_id    = -1;
        slave_id     = -1;
        timestamp    = 0;
        cycle        = 0;
        severity     = ERROR;
    endfunction

    function string severity_name();
        case (severity)
            INFO:    return "INFO";
            WARNING: return "WARNING";
            ERROR:   return "ERROR";
            FATAL:   return "FATAL";
        endcase
    endfunction

    virtual function string convert2string();
        return $sformatf(
            "[%s][%s][%s] %s: %s (addr=0x%0h data=0x%0h master=%0d slave=%0d time=%0t cycle=%0d)",
            severity_name(), protocol, rule_category, rule_name, detail,
            address, data, master_id, slave_id, timestamp, cycle
        );
    endfunction
endclass
