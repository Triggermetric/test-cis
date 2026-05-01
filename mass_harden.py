import subprocess
import time
import json
import re

def run_az_cmd(vm_name, cmd):
    rg = "rg-cis-cassandra"
    print(f"[{vm_name}] Running: {cmd}")
    az_cmd = [
        "az.cmd", "vm", "run-command", "invoke",
        "-g", rg,
        "-n", vm_name,
        "--command-id", "RunShellScript",
        "--scripts", cmd
    ]
    return subprocess.Popen(az_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=True)

def main():
    nodes = ["cis-cassandra-db1", "cis-cassandra-db2", "cis-cassandra-db3"]
    processes = []
    
    print("Initiating full hardening (all sections) on all nodes in parallel...")
    for node in nodes:
        # We run the toolkit already deployed at /opt/cis
        p = run_az_cmd(node, "sudo bash /opt/cis/cis-tool.sh harden all")
        processes.append((node, p))
    
    print("Waiting for completion (this may take a few minutes)...")
    for node, p in processes:
        stdout, stderr = p.communicate()
        if p.returncode == 0:
            print(f"\n==========================================")
            print(f"NODE: {node}")
            print(f"==========================================")
            try:
                data = json.loads(stdout)
                msg = data.get("value", [{}])[0].get("message", "")
                match = re.search(r'\[stdout\](.*?)\[stderr\]', msg, re.DOTALL)
                if match:
                    print(match.group(1).strip())
                else:
                    print(msg.strip() if msg else stdout)
            except Exception:
                print(stdout)

        else:
            print(f"[{node}] Failed")
            print(stderr)

if __name__ == "__main__":
    main()
