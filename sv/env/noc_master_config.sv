// noc_master_config.sv - Per-master configuration object
class noc_master_config extends uvm_object;
    string          name;
    int             master_id;
    string          protocol;
    int             thread_id_width;
    bit [63:0]      target_slaves[$];   // list of slave base addrs this master can access
    string          svt_agent_path;
    bit             active;

    `uvm_object_utils_begin(noc_master_config)
        `uvm_field_string(name, UVM_DEFAULT)
        `uvm_field_int(master_id, UVM_DEFAULT)
        `uvm_field_string(protocol, UVM_DEFAULT)
        `uvm_field_int(thread_id_width, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "noc_master_config");
        super.new(name);
        this.name            = "";
        this.master_id       = 0;
        this.protocol        = "AXI4";
        this.thread_id_width = 4;
        this.svt_agent_path  = "";
        this.active          = 1'b1;
    endfunction

    function bit can_access(bit [63:0] addr, noc_slave_config slaves[$]);
        foreach (target_slaves[i]) begin
            foreach (slaves[j]) begin
                if ((target_slaves[i] == slaves[j].base_addr) && slaves[j].is_in_range(addr))
                    return 1'b1;
            end
        end
        if (target_slaves.size() == 0) return 1'b1;  // all access if no restriction
        return 1'b0;
    endfunction
endclass
