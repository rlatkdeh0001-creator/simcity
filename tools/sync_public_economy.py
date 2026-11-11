"""Synchronize the sole editable economics CSV into the exported Godot resources."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[1]
def main():
 source=ROOT/'docs/economy-balance/ECONOMY_BALANCE.csv';target=ROOT/'cities_do/assets/economy/ECONOMY_BALANCE.csv.txt'
 target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
 print('PUBLIC_ECONOMY_SYNC',hashlib.sha256(target.read_bytes()).hexdigest())
if __name__=='__main__':main()
