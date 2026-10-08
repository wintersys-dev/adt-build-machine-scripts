---
- name: Clear All Rules From A Specific Linode Firewall By Label
  hosts: localhost
  gather_facts: false
  vars_files:
    - "{{ path_to_vault_file }}"
  vars:
    default_inbound_policy: "DROP"  
    default_outbound_policy: "ACCEPT" 

  tasks:
    - name: Ensure Linode API token is available
      ansible.builtin.fail:
        msg: "Please set the LINODE_API_TOKEN environment variable before running this playbook."
      when: linode_api_token | length == 0

    - name: Look up firewall details to find the ID by label
      ansible.builtin.uri:
        url: "https://linode.com"
        method: GET
        headers:
          Authorization: "Bearer {{ linode_api_token }}"
        status_code: 200
      register: list_firewalls_response

    - name: Extract firewall ID matching the target label
      ansible.builtin.set_fact:
        target_firewall_id: "{{ (list_firewalls_response.json.data | selectattr('label', 'equalto', target_firewall_label) | map(attribute='id') | list)[0] | default(none) }}"

    - name: Stop execution if firewall label is not found
      ansible.builtin.fail:
        msg: "Could not find a Linode firewall with the label: {{ target_firewall_label }}"
      when: target_firewall_id is none

    - name: Purge all inbound and outbound rules regardless of content
      ansible.builtin.uri:
        url: "https://linode.com/{{ target_firewall_id }}/rules"
        method: PUT
        headers:
          Authorization: "Bearer {{ linode_api_token }}"
          Content-Type: "application/json"
        body_format: json
        body:
          inbound: []
          outbound: []
          inbound_policy: "{{ default_inbound_policy }}"
          outbound_policy: "{{ default_outbound_policy }}"
        status_code: 200
      register: api_response

    - name: Confirm successful removal
      ansible.builtin.debug:
        msg: "Successfully cleared all rules from Firewall label '{{ target_firewall_label }}' (ID: {{ target_firewall_id }})."

