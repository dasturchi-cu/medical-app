import os
import sys
import paramiko

vps_ip = "84.46.243.149"
vps_user = "root"
vps_pass = "muhammad9085"
local_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
remote_root = "/app/neuroscience"

print(f"Connecting to {vps_user}@{vps_ip}...")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    ssh.connect(vps_ip, username=vps_user, password=vps_pass, timeout=15)
    print("SSH connection established successfully!")
except Exception as e:
    print(f"Failed to connect: {e}")
    sys.exit(1)

# Helper function to create directories remotely
def remote_mkdir(sftp, path):
    try:
        sftp.mkdir(path)
        print(f"Created remote directory: {path}")
    except OSError:
        pass # Directory already exists

sftp = ssh.open_sftp()

print("Setting up remote directory structure...")
remote_mkdir(sftp, remote_root)
remote_mkdir(sftp, f"{remote_root}/scripts")
remote_mkdir(sftp, f"{remote_root}/backend")
remote_mkdir(sftp, f"{remote_root}/backend/fastapi")
remote_mkdir(sftp, f"{remote_root}/backend/admin_panel")

# Files to upload from the root
root_files = ["docker-compose.yml", "nginx.conf", "redis.conf", ".env.production"]
for f in root_files:
    local_path = os.path.join(local_root, f)
    remote_path = f"{remote_root}/{f}"
    print(f"Uploading {f}...")
    sftp.put(local_path, remote_path)

# Scripts to upload
script_files = ["backup.sh", "deploy.sh", "monitor.sh"]
for f in script_files:
    local_path = os.path.join(local_root, "scripts", f)
    remote_path = f"{remote_root}/scripts/{f}"
    print(f"Uploading scripts/{f}...")
    sftp.put(local_path, remote_path)

# Function to recursively upload a folder
def upload_dir(local_dir, remote_dir):
    remote_mkdir(sftp, remote_dir)
    for entry in os.scandir(local_dir):
        if entry.is_dir():
            # Skip python virtual environments, cache, node_modules, and git folders
            if entry.name in {".freshvenv", ".testvenv", "__pycache__", ".git", "node_modules", ".next", "build", ".dart_tool"}:
                continue
            upload_dir(entry.path, f"{remote_dir}/{entry.name}")
        elif entry.is_file():
            # Skip python cache files
            if entry.name.endswith(".pyc"):
                continue
            # Skip local env files except requirements.txt or config if needed
            # (we already uploaded .env.production)
            if entry.name == ".env" or entry.name == ".env.local":
                continue
            
            local_file_path = entry.path
            remote_file_path = f"{remote_dir}/{entry.name}"
            print(f"Uploading {entry.path.replace(local_root, '')}...")
            sftp.put(local_file_path, remote_file_path)

print("Uploading FastAPI backend codebase...")
upload_dir(os.path.join(local_root, "backend", "fastapi"), f"{remote_root}/backend/fastapi")

print("Uploading Next.js admin_panel codebase...")
upload_dir(os.path.join(local_root, "backend", "admin_panel"), f"{remote_root}/backend/admin_panel")

sftp.close()
print("All files uploaded successfully!")

# Run deploy.sh remotely
print("Executing deploy.sh on the VPS...")
ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(f"sed -i -e 's/\\r$//' {remote_root}/scripts/*.sh && chmod +x {remote_root}/scripts/deploy.sh && {remote_root}/scripts/deploy.sh")

# Stream output in real-time
for line in ssh_stdout:
    try:
        encoding = sys.stdout.encoding or 'utf-8'
        safe_line = line.encode(encoding, errors='replace').decode(encoding, errors='replace')
        print(f"[VPS] {safe_line.strip()}")
    except Exception:
        print(f"[VPS] {line.encode('ascii', 'ignore').decode('ascii').strip()}")

# Print errors if any
try:
    err = ssh_stderr.read().decode('utf-8', errors='replace').strip()
    if err:
        encoding = sys.stdout.encoding or 'utf-8'
        safe_err = err.encode(encoding, errors='replace').decode(encoding, errors='replace')
        print(f"[VPS ERROR] {safe_err}")
except Exception as e:
    print(f"Failed to read stderr: {e}")

ssh.close()
print("Deployment process finished!")
