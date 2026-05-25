Plan — Are You My Mother (AYMM): Multi-Provider Ralph Loop                        
                                                                                     
  ## Context                                                                         
                                                                                     
  The Ralph Loop is an autonomous Claude Code agent that executes coding tasks inside
  Docker, one step at a time, using Claude for every iteration. That works well but  
  burns Anthropic API credits on every step — even for straightforward, mechanical   
  work that a free AI could handle.                                                  
                                                                                     
  AYMM adds a cost-optimization wrapper: before Claude touches a task, the system    
  tries it with free-tier AI providers (Gemini, Groq, Mistral, OpenRouter). If a free
  AI produces output that passes the test suite, Claude never gets involved. If they 
  all fail, the task escalates back to Claude (the nest / the snort). If Claude also 
  fails, one more free-AI round runs before BLOCKED + phone alert fires.             
                                                                                     
  The metaphor from the children's book: Ralph the baby bird falls out of the nest   
  and asks each animal "Are you my mother?" — each free AI gets one chance to answer 
  yes (pass the tests). If none are his mother, the snort (the scary machine) lifts  
  him back to the nest (Claude).                                                     
                                                                                     
  This project builds AYMM using itself — the existing Ralph Loop (Claude-powered)   
  will autonomously write the AYMM scripts. When the loop finishes, this repo        
  contains both  ralph.sh  (pure Claude) and  aymm.sh  (free-AI-first). Future       
  projects fork and run whichever fits their budget. (only problem with this is that AYMM might not be able to run independently, what do you think?)                                          
                                                                                     
  --------                                                                           
                                                                                     
  ## What Gets Built                                                                 
                                                                                     
  New files created by the loop:                                                     
                                                                                     
  File             │Purpose                                                          
  ─────────────────┼─────────────────────────────────────────────────────────────────
   provider-config…│API endpoints, model names, env var names per provider           
   run_agent_task.…│Context bundle → API call → parse XML → write files → run tests …
   aymm-loop.sh    │Outer provider coordinator + inner execution loop (replaces loop…
   aymm.sh         │Host-side wrapper (like ralph.sh but invokes aymm-loop.sh)       
   prompt-aymm.md  │Navigation wrapper for context bundling (identifies current step…
                                                                                     
  Modified files:                                                                    
                                                                                     
  File              │Change                                                          
  ──────────────────┼────────────────────────────────────────────────────────────────
   Dockerfile       │Add env var passthrough for GEMINI_API_KEY, GROQ_API_KEY, MISTR…
   init-firewall.sh │Add firewall allowlist entries for provider domains             
   README.md        │Add AYMM usage section                                          
                                                                                     
  --------                                                                           
                                                                                     
  ## Architecture Decisions                                                          
                                                                                     
  Stack: bash + curl + jq. Consistent with existing loop.sh. No new language         
  dependencies.                                                                      
                                                                                     
  Free AI output format: XML file blocks. The task runner asks the free AI to wrap   
  every modified file like:                                                          
                                                                                     
    <file path="src/foo.js">                                                         
    ...full file content...                                                          
    </file>                                                                          
                                                                                     
  Parsed with grep/sed in bash. Simple and reliable.                                 
                                                                                     
  Test method: Run the project's test command (from ARCHITECTURE.md). No Claude      
  semantic review per attempt — that would spend Claude tokens on every free-AI      
  attempt, defeating the purpose.                                                    
                                                                                     
  Provider priority order:                                                           
                                                                                     
  1. Gemini 2.5 Flash — most generous free tier (1500 RPD), large context window     
  2. Mistral Large — Codestral is coding-specific, good rate limits                  
  3. Groq Llama 3.3 70B — fastest inference, strict per-minute caps                  
  4. OpenRouter free models — most limited (200 RPD), but broadest model variety     
                                                                                     
  Claude fallback: When all free AIs fail a task, AYMM calls  loop.sh  as-is — no    
  duplication of Claude logic.                                                       
                                                                                     
  Escalation per task:                                                               
                                                                                     
  • Free AI fails 3×(might want to make it 2, so it does not eat up to much free usage) on same provider → switch provider (red flag: hallucination)    
  • HTTP 429 from provider → immediate switch to next provider                       
  • HTTP 403 from provider → mark exhausted, skip for remainder of session           
  • All 4 providers fail same task → invoke loop.sh (Claude handles it)              
  • Claude fails same task → one more free-AI round(might not want do a second round of AYMM so it does not eat up free usage) → BLOCKED.md + phone alert       
                                                                                     
  Rate limit replenishment: After cycling through all providers with no success,     
  sleep 1 hour then restart from Provider 1.(this might need to be a toggle, like set it and forget it, but I don't know if that really makes sense, but we could have a thing that flags if all the ai's are maxed out on usage, to aleart user and ask if they just want to run ralph with out aymm or tell them how long till they reset and ask if they want to wait till then, what do you think?)                                         
                                                                                     
  Firewall additions for init-firewall.sh:                                           
                                                                                     
  •  generativelanguage.googleapis.com  — Gemini                                     
  •  api.groq.com  — Groq                                                            
  •  api.mistral.ai  — Mistral                                                       
  •  openrouter.ai  — OpenRouter                                                     
                                                                                     
  --------                                                                           
                                                                                     
  ## ARCHITECTURE.md to Create                                                       
                                                                                     
    # AYMM Architecture — Are You My Mother (Multi-Provider Ralph Loop)              
                                                                                     
    ## What This Is                                                                  
    An extension of the Ralph Loop that routes autonomous coding tasks through free  
  AI APIs before                                                                     
    falling back to Claude. Run `bash aymm.sh` instead of `bash ralph.sh` to use free-
  AI-first execution.                                                                
                                                                                     
    ## Stack                                                                         
    - Shell: bash                                                                    
    - HTTP client: curl                                                              
    - JSON parsing: jq                                                               
    - Container: Docker (extends existing ralph infrastructure)                      
    - Test gate: inherits from target project's ARCHITECTURE.md test command         
                                                                                     
    ## Key Files                                                                     
    - `aymm.sh` — host wrapper (invoke this instead of ralph.sh)                     
    - `aymm-loop.sh` — container orchestrator (outer provider loop + inner execution 
  loop)                                                                              
    - `run_agent_task.sh` — per-provider task runner                                 
    - `provider-config.sh` — API configuration per provider                          
    - `prompt-aymm.md` — navigation wrapper for free AI context bundling             
    - `ralph.sh` / `loop.sh` — unchanged; used as Claude fallback                    
                                                                                     
    ## Provider Priority                                                             
    1. Gemini 2.5 Flash (GEMINI_API_KEY)                                             
    2. Mistral Large (MISTRAL_API_KEY)                                               
    3. Groq Llama 3.3 70B (GROQ_API_KEY)                                             
    4. OpenRouter free models (OPENROUTER_API_KEY)                                   
    5. Claude fallback via existing loop.sh                                          
                                                                                     
    ## Escalation                                                                    
    - 3×(might want to change to 2) consecutive failures on one provider → switch provider                      
    - HTTP 429 → immediate provider switch                                           
    - HTTP 403 → mark provider exhausted                                             
    - All providers fail one task → escalate to Claude (loop.sh)                     
    - Claude fails same task → one more free-AI round(might want to scrap that) → BLOCKED                      
                                                                                     
    ## Environment Variables Required                                                
    - ANTHROPIC_API_KEY (existing)                                                   
    - GEMINI_API_KEY                                                                 
    - GROQ_API_KEY                                                                   
    - MISTRAL_API_KEY                                                                
    - OPENROUTER_API_KEY                                                             
                                                                                     
    ## Test Command                                                                  
    (Set per project in ARCHITECTURE.md — AYMM inherits it)                          
                                                                                     
    ## Ralph Settings                                                                
    autonomy: high (might want not have it set to high for the first time running it)                                                                  
                                                                                     
    ## Firewall Additions                                                            
    generativelanguage.googleapis.com                                                
    api.groq.com                                                                     
    api.mistral.ai                                                                   
    openrouter.ai                                                                    
                                                                                     
  --------                                                                           
                                                                                     
  ## PLAN.md to Create                                                               
                                                                                     
    # PLAN — Are You My Mother (AYMM)                                                
                                                                                     
    Status: In Progress                                                              
                                                                                     
    ## Sub-Plans                                                                     
    - [ ] Phase 1: Provider Infrastructure — [plan](plans/provider-infrastructure.md)
    - [ ] Phase 2: Task Runner — [plan](plans/task-runner.md)                        
    - [ ] Phase 3: AYMM Loop Orchestrator — [plan](plans/aymm-orchestrator.md)       
    - [ ] Phase 4: Integration & README — [plan](plans/integration.md)               
                                                                                     
  --------                                                                           
                                                                                     
  ## Sub-Plans to Create                                                             
                                                                                     
  ### plans/provider-infrastructure.md                                               
                                                                                     
  Tasks:                                                                             
                                                                                     
  • Write  provider-config.sh  — define PROVIDERS array, API_URL, MODEL, API_KEY_VAR 
  per provider                                                                       
  • Update  Dockerfile  — add ENV passthrough for all 4 provider keys                
  • Update  init-firewall.sh  — add 4 new domain allowlist entries                   
  • Write connectivity test script ( test-providers.sh ) — curl each provider with a 
  minimal prompt, report which keys are set and responding                           
                                                                                     
  ### plans/task-runner.md                                                           
                                                                                     
  Tasks:                                                                             
                                                                                     
  • Write  run_agent_task.sh  skeleton — argument parsing, provider dispatch, exit   
  codes                                                                              
  • Implement context bundler — reads current task file, finds next unchecked step,  
  reads mentioned file paths, assembles prompt                                       
  • Implement Gemini API call — POST to generativelanguage.googleapis.com, handle    
  429/403                                                                            
  • Implement OpenAI-compatible API call (Groq, Mistral, OpenRouter) — shared curl   
  function                                                                           
  • Implement XML response parser — extract  <file path="...">...</file>  blocks,    
  write to disk                                                                      
  • Implement test runner — run test command from ARCHITECTURE.md, return exit 0/2   
  • Integration test: run against a known simple task with each provider             
                                                                                     
  ### plans/aymm-orchestrator.md                                                     
                                                                                     
  Tasks:                                                                             
                                                                                     
  • Write  aymm-loop.sh  skeleton — source provider-config.sh, read ARCHITECTURE.md  
  autonomy setting                                                                   
  • Implement inner loop — call run_agent_task.sh, read exit code, track consecutive 
  failures                                                                           
  • Implement provider switching — on 429 or 3× failures, advance provider index     
  • Implement exhaustion cycle — when all 4 providers tried, sleep 3600, reset index 
  • Implement Claude escalation — when all providers fail same task, write  .        
  ralph/aymm-escalate.txt , exec loop.sh                                             
  • Implement double-fail BLOCKED — detect second round free-AI failure, write       
  BLOCKED.md, send ntfy alert                                                        
  • Recovery state tracking — write  .ralph/aymm-provider-state.json  each iteration 
  (active provider, failure counts)                                                  
                                                                                     
  ### plans/integration.md                                                           
                                                                                     
  Tasks:                                                                             
                                                                                     
  • Write  aymm.sh  — host wrapper (mirrors ralph.sh but passes provider env vars and
  invokes aymm-loop.sh)                                                              
  • Write  prompt-aymm.md  — minimal navigation wrapper for free AI: read task file, 
  identify step, list relevant files, format XML output instruction                  
  • Update README.md — add AYMM section: required env vars,  bash aymm.sh  usage, how
  escalation works                                                                   
  • End-to-end smoke test: set up a minimal test project, run  bash aymm.sh , verify 
  at least one provider attempts a task                                              
                                                                                     
  --------                                                                           
                                                                                     
  ## Verification                                                                    
                                                                                     
  After the loop completes, verify manually:                                         
                                                                                     
  1.  bash test-providers.sh  — all 4 provider keys connect and return a response    
  2.  bash aymm.sh plan  — breakdown mode works (generates task files like ralph.sh  
  plan does)                                                                         
  3. Create a minimal test project with a trivial task (e.g., "write hello world to  
  src/index.js, test command: node src/index.js") and run  bash aymm.sh  — confirm:  
    • A free AI attempts the task                                                    
    • Output is applied to disk                                                      
    • Test runs and passes                                                           
    • Commit is made                                                                 
  4. Simulate 429: temporarily set a bad API key, confirm provider rotation happens  
  5. Simulate all failures: bad keys for all 4 providers, confirm loop.sh Claude     
  fallback fires                                                                     
  6. Check  .ralph/aymm-provider-state.json  is written each iteration               
  7. Check  README.md  has the AYMM section                                          
                                                                                     
  --------                                                                           
                                                                                     
  ## Execution Order                                                                 
                                                                                     
  Run phases sequentially — each phase's output is depended on by the next:          
                                                                                     
  1. Phase 1 first — Dockerfile + firewall changes mean the container has provider   
  access                                                                             
  2. Phase 2 next — run_agent_task.sh is the core primitive everything else calls    
  3. Phase 3 next — aymm-loop.sh depends on run_agent_task.sh existing               
  4. Phase 4 last — aymm.sh and prompt-aymm.md are the final integration layer       
                                                                                     
  Before starting execution: create  ARCHITECTURE.md  (manually, interactively — it's
  read-only to the agent). Then run  bash ralph.sh plan  to generate task files from 
  the sub-plans, then  bash ralph.sh  to execute.               