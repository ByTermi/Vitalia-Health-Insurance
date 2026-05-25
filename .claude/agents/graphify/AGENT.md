---
name: graphify-agent
description: Generates a knowledge graph from a codebase or research corpus in isolation, returning only a summary to avoid flooding the main context with large intermediate data.
skill_counterpart: /graphify
agent_type: general-purpose
run_in_background: false
---

# Graphify Agent

Delegates the knowledge graph generation pipeline to an isolated agent. Graphify processes entire directory trees, extracts hundreds of nodes and edges, runs community detection, and writes multiple output files — it should never run inline.

## When to use this vs `/graphify`

**Always use this agent.** Graphify generates large intermediate data (nodes, edges, adjacency lists) that would saturate the main context window. The agent processes it all and writes output files directly, returning only a summary.

## How to invoke

```
Agent({
  description: "Build knowledge graph for [path]",
  subagent_type: "general-purpose",
  run_in_background: false,
  prompt: """
You are a knowledge graph engineer. Build a knowledge graph for the files at: [PATH]
[Options: --mode deep | --directed | --no-viz | --update (incremental)]

PIPELINE:

PHASE 1 — Discovery
List all files in [PATH] recursively. Exclude: node_modules, .git, dist, build, __pycache__, *.lock, *.log.
For each file, record: path, extension, size, last modified.

PHASE 2 — Node extraction
For each file:
  - Extract its identity as a node: { id, label, type, path, summary }
  - type = "file" | "function" | "class" | "component" | "module" | "concept"
  - summary = 1-sentence description of what the file/entity does

For code files, also extract named exports, classes, and functions as child nodes.
For markdown files, extract H1/H2 headings as concept nodes.

PHASE 3 — Edge extraction
For each node pair, extract relationships:
  EXPLICIT edges (from actual imports, links, references):
    - imports / depends_on: file A imports from file B
    - references: file A mentions entity from file B
    - links_to: markdown A has a link to markdown B

  INFERRED edges (from semantic similarity — label clearly):
    - similar_topic: two files/concepts share a clear theme
    - extends / implements: class hierarchy

PHASE 4 — Community detection
Group nodes into communities using label propagation:
  - Start: each node in its own community
  - Iterate: each node adopts the most common community label among its neighbors
  - Stop when stable or after 10 iterations
  - Name each community by its most central node

PHASE 5 — Write output files to [PATH]:

  graph.json: {
    "nodes": [{ "id", "label", "type", "path", "community", "degree" }],
    "edges": [{ "source", "target", "type", "weight", "inferred": bool }],
    "communities": [{ "id", "name", "size", "nodes": [] }],
    "metadata": { "generated", "node_count", "edge_count", "community_count" }
  }

  graph.html: Self-contained interactive visualization using D3 or vis.js (embed the library inline).
    - Nodes colored by community
    - Node size proportional to degree (connection count)
    - Edge thickness by weight
    - Click node → show details panel (path, type, summary, connections)
    - Community legend on the side
    - Search box to highlight nodes by name

  GRAPH_REPORT.md: Plain-language summary:
    # Knowledge Graph Report: [path]
    Generated: [date]

    ## Overview
    - [N] nodes, [M] edges, [K] communities
    - Most connected nodes: [top 5 by degree]
    - Isolated nodes (no connections): [list — these are orphans worth reviewing]

    ## Communities
    | Community | Size | Central node | Theme |
    ...

    ## Key Relationships
    [5–10 most interesting edges or patterns discovered]

    ## Audit Notes
    - Inferred edges: [N] — review for accuracy
    - Orphan nodes: [list] — consider linking or removing
    - Densest cluster: [community name] — [what it suggests about architecture]

Return a brief summary: node count, edge count, community count, top 3 most-connected nodes, and confirm which files were written.
  """
})
```

## What the agent returns

Three files written to `[PATH]`: `graph.json`, `graph.html`, `GRAPH_REPORT.md`.
The agent returns a brief summary (counts + top nodes). Present that summary and tell the user to open `graph.html` in a browser and `GRAPH_REPORT.md` in the vault.
