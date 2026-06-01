// noc_master_config.sv - Per-master configuration object
class noc_master_config extends uvm_object;
    string          name;
    int             master_id;
    string          protocol;
    int             thread_id_width;
    string          allowed_slave_names[$];  // slave names this master can access (access matrix)
    int             allowed_slave_ids[$];    // resolved slave_id from name lookup
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

    // Check if this master is allowed to access a given slave (by address)
    function bit can_access_addr(bit [63:0] addr, noc_env_cfg cfg);
        noc_slave_config slv = cfg.find_slave_by_addr(addr);
        if (slv == null) return 1'b0;
        return can_access_slave(slv);
    endfunction

    // Check by slave name (access matrix primary key)
    function bit can_access_slave_name(string slave_name);
        foreach (allowed_slave_names[i])
            if (allowed_slave_names[i] == slave_name) return 1'b1;
        if (allowed_slave_names.size() == 0) return 1'b1;  // all access if no restriction
        return 1'b0;
    endfunction

    function bit can_access_slave(noc_slave_config slave);
        if (slave == null) return 1'b0;
        return can_access_slave_name(slave.name);
    endfunction

    // Resolve allowed_slave_names -> allowed_slave_ids using config
    function void resolve_slave_ids(noc_env_cfg cfg);
        allowed_slave_ids.delete();
        foreach (allowed_slave_names[i]) begin
            noc_slave_config slv = cfg.find_slave_by_name(allowed_slave_names[i]);
            if (slv != null)
                allowed_slave_ids.push_back(slv.slave_id);
        end
    endfunction

    // Get list of slaves that can access this master (reverse lookup for conflict test)
    function void get_accessible_slaves(noc_env_cfg cfg, ref noc_slave_config slaves[$]);
        slaves.delete();
        for (int i = 0; i < cfg.num_slaves; i++) begin
            if (cfg.slaves[i] != null && can_access_slave(cfg.slaves[i]))
                slaves.push_back(cfg.slaves[i]);
        end
    end

    function string get_allowed_slaves_str();
        string s = "";
        foreach (allowed_slave_names[i]) begin
            if (i > 0) s = {s, ","};
            s = {s, allowed_slave_names[i]};
        end
        return (s == "") ? "ALL" : s;
    endfunction
endclass
