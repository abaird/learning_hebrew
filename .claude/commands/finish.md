Complete the finish-feature workflow:

1. Run the test suite with `script/test.sh`
   - If there are any failures, STOP and report them so we can fix them
   - Do not proceed until all tests pass

2. Run `bundle exec rubocop -A` to auto-fix any linting issues
   - If there are unfixable issues, report them

3. Update CLAUDE.md with a summary of the changes made in this session

4. Write a concise commit message summarizing the changes and ask for permission to commit
   - Include what was changed and why
   - Use the standard format with Claude Code footer

Do NOT skip any steps. Each step must complete successfully before proceeding to the next.
