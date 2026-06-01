// noc_slave_config.sv - Per-slave configuration object
`include "noc_macros.svh"

class noc_special_region extends uvm_object;
    string name;
    bit [63:0]  base;
    bit [63:0]  range;
    string      access;  // "R", "W", "RW"

    `uvm_object_utils(noc_special_region)

    function new(string name = "noc_special_region");
        super.new(name);
        this.name   = "";
        this.base   = 64'h0;
        this.range  = 64'h0;
        this.access = "RW";
    endfunction

    function bit is_in_region(bit [63:0] addr);
        return (addr >= base) && (addr < (base + range));
    endfunction
endclass

class noc_slave_config extends uvm_object;
    string                          name;
    bit [63:0]                      base_addr;
    bit [63:0]                      addr_range;
    int                             slave_id;
    string                          supported_protocols[$];
    string                          supported_burst[$];
    int                             max_len;
    int                             max_size;
    int                             outstanding_capability;
    bit                             alignment_required;
    bit                             interleaving_supported;
    bit                             write_enable;
    int                             read_latency_min;
    int                             read_latency_max;
    int                             write_latency_min;
    int                             write_latency_max;
    noc_special_region              special_regions[$];
    string                          svt_agent_path;  // hierarchical SVT agent path

    `uvm_object_utils_begin(noc_slave_config)
        `uvm_field_string(name, UVM_DEFAULT)
        `uvm_field_int(base_addr, UVM_DEFAULT)
        `uvm_field_int(addr_range, UVM_DEFAULT)
        `uvm_field_int(slave_id, UVM_DEFAULT)
        `uvm_field_int(max_len, UVM_DEFAULT)
        `uvm_field_int(max_size, UVM_DEFAULT)
        `uvm_field_int(outstanding_capability, UVM_DEFAULT)
        `uvm_field_int(alignment_required, UVM_DEFAULT)
        `uvm_field_int(write_enable, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "noc_slave_config");
        super.new(name);
        this.name                   = "";
        this.base_addr              = 64'h0;
        this.addr_range             = 64'h0;
        this.slave_id               = -1;
        this.max_len                = 15;
        this.max_size               = 7;
        this.outstanding_capability = 16;
        this.alignment_required     = 1'b1;
        this.interleaving_supported = 1'b1;
        this.write_enable           = 1'b1;
        this.read_latency_min       = 0;
        this.read_latency_max       = 16;
        this.write_latency_min      = 0;
        this.write_latency_max      = 16;
        this.svt_agent_path         = "";
    endfunction

    function bit is_in_range(bit [63:0] addr);
        return (addr >= base_addr) && (addr < (base_addr + addr_range));
    endfunction

    function bit [63:0] get_end_addr();
        return base_addr + addr_range - 1;
    endfunction

    function bit supports_protocol(string proto);
        foreach (supported_protocols[i])
            if (supported_protocols[i] == proto) return 1'b1;
        return 1'b0;
    endfunction

    function bit supports_burst_type(string bt);
        foreach (supported_burst[i])
            if (supported_burst[i] == bt) return 1'b1;
        return 1'b0;
    endfunction

    function noc_special_region find_region(bit [63:0] addr);
        foreach (special_regions[i])
            if (special_regions[i].is_in_region(addr))
                return special_regions[i];
        return null;
    endfunction

    function string get_all_protocols_str();
        string s = "";
        foreach (supported_protocols[i]) begin
            if (i > 0) s = {s, ","};
            s = {s, supported_protocols[i]};
        end
        return (s == "") ? "NONE" : s;
    endfunction
endclass
