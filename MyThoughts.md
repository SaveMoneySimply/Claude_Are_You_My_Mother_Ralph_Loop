## My Thoughts
-change handoff so that it does not delete but sends file to a archive folder named handoffs
-change aymm so that the error message is sent back to the free ai, twice before moving on.
-Handoff, have a handoff file in aymm, a general overview of the project and tasks. add each task read out added as the project goes?
-Should we give the next ai, the previous ai's attempts to solve and the errors they got?
-OpenRouter model rotation: if one free model hits its quota, try the next free model on OpenRouter before giving up. Each :free model has its own separate quota. Would add a provider_fallback_models() function to provider-config.sh. Low priority — do after basic loop is working.
-Extending free quota: two options that compound — (1) multiple OpenRouter accounts, each with its own free quota on the same models; (2) go direct to each company's own free API (DeepSeek, Poolside, NVIDIA etc.) for more generous quotas than the OpenRouter-routed versions. Add the best direct APIs as extra providers in the chain if rate limits become a problem.