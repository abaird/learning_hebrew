# Implementation Phase Rules

**Usage:** `/implement-phase <phase_number>`

**Arguments:**
- `<phase_number>`: The phase number to implement (e.g., 1, 2, 3)

---

You are implementing **Phase {PHASE_NUMBER}** of the current project.

Follow these guidelines:

## Before Starting

1. **Review phase requirements thoroughly**
   - Find and read the project documentation in the `projects/` directory (skip `archive/` folder)
   - Look for Phase {PHASE_NUMBER} in the documentation
   - If phases are not clearly labeled, search for section headings like "Phase {PHASE_NUMBER}" or "Step {PHASE_NUMBER}"
   - Identify all deliverables and acceptance criteria for this specific phase
   - Note any dependencies on previous phases
   - If you cannot find Phase {PHASE_NUMBER}, ask the user for clarification

2. **Clarify ambiguities**
   - Ask questions if requirements are unclear
   - Verify assumptions about implementation approach
   - Confirm technology choices if multiple options exist
   - If you have been asked to implement a phase but the documentation isn't up to date, either update the documentation if you were directly involved in it's implementation or ask for clarification on what to do

3. **Create detailed task list**
   - Use TodoWrite to create granular, actionable tasks
   - Break down complex tasks into smaller steps if they aren't already broken down in the docs

## During Implementation

1. **Follow TDD approach**
   - Write tests first for new functionality
   - Ensure existing tests pass before making changes
   - Add test coverage for edge cases and error conditions

2. **Incremental progress**
   - Make small, focused changes
   - Test after each significant change (use the script/test.sh script for testing)
   - Commit frequently with descriptive messages
   - Update TodoWrite status as tasks complete

3. **Code quality**
   - Follow existing code style and conventions
   - Use proper error handling and validation
   - Avoid hardcoded values (use environment variables or config)
   - Watch for N+1 queries and performance issues
   - Never commit secrets or sensitive data

4. **Documentation as you go**
   - Add inline comments for complex logic, but comment sparingly
   - Update relevant documentation files
   - Keep CLAUDE.md in sync with architectural changes

## After Completion

1. **Verification**
   - Run full test suite and ensure all tests pass
   - Run Rubocop and fix any style violations
   - Manually test critical user-facing features if it's not too complex or ask me to test for you
   - Verify no regressions in existing functionality

2. **Documentation updates**
   - Update CLAUDE.md with new features/architecture
   - Add usage examples if applicable
   - Document any new environment variables or config
   - Note any breaking changes or migration requirements

3. **Final cleanup**
   - Remove debug code, console.logs, or temporary changes
   - Ask about any remaining TODOs 
   - Review git diff before committing
   - Write comprehensive commit message summarizing the phase
   - Ask me before committing anything to approve the commit message
   - Do not push - I will handle that

4. **Deployment considerations**
   - Note any required database migrations
   - Document any new dependencies or gems
   - Identify any environment-specific configurations

## Security Checklist

- [ ] No secrets, API keys, or passwords in code
- [ ] Input validation on all user-provided data
- [ ] Proper authorization checks (Pundit policies)
- [ ] SQL injection prevention (use parameterized queries)
- [ ] XSS prevention (proper HTML escaping)
- [ ] CSRF protection enabled
- [ ] Sensitive data encrypted at rest and in transit

## Performance Checklist

- [ ] Database queries optimized (use includes/joins)
- [ ] No N+1 query problems
- [ ] Appropriate database indexes added
- [ ] Lazy loading for large files/assets
- [ ] Pagination for large result sets
- [ ] Cache expensive operations where appropriate

## Accessibility & UX

- [ ] Semantic HTML structure
- [ ] Clear error messages for users
- [ ] Loading states for async operations

---

**Note:** These are guidelines, not rigid rules. Use judgment and adapt as needed for the specific phase requirements.
