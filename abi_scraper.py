import json

f = open("./vaultabi.json", "r")

f_raw = f.read()

g = json.loads(f_raw)

print("\nEVENTS\n---")
for x in range(len(g)):
    if g[x]["type"] == "event":
        print(g[x]["name"]) 

print("\nFUNCTIONS\n---")
for x in range(len(g)):
    if g[x]["type"] == "function":
        print(g[x]["name"]) 