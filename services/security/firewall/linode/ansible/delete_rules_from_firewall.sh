---
- name: Clear Linode Firewall Rules by Label
  hosts: localhost
  gather_facts: false
  vars_files:
    - "{{ path_to_vault_file }}"
  vars:
    linode_api_url: "https://api.linode.com/v4/networking/firewalls"

  tasks:
    - name: Get all firewalls
      ansible.builtin.uri:
        url: "{{ linode_api_url }}"
        headers:
          Authorization: "Bearer {{ linode_api_token }}"
      register: res

    - name: Clear rules for the matching firewall label
      ansible.builtin.uri:
        url: "{{ linode_api_url }}/{{ item.id }}/rules"
        method: PUT
        headers:
          Authorization: "Bearer {{ linode_api_token }}"
          Content-Type: "application/json"
        body_format: json
        body:
          inbound: []
          outbound: []
          inbound_policy: "DROP"
          outbound_policy: "ACCEPT"
      loop: "{{ res.json.data }}"
      when: item.label == target_firewall_label
      loop_control:
        label: "{{ item.label }}"

    - name: Confirm successful removal
      ansible.builtin.debug:
        msg: "Successfully cleared all rules from Firewall label '{{ target_firewall_label }}' (ID: {{ target_firewall_id }})."

