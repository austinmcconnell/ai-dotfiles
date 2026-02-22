# Code Comment Guidance

When writing or suggesting code, follow these guidelines for comments to maintain clean, readable
code without unnecessary noise.

## General Principles

1. **Avoid redundant comments** that merely repeat what the code already clearly communicates
2. **Focus on the "why" not the "what"** when adding comments
3. **Comment complex logic** that isn't immediately obvious
4. **Use docstrings** for functions, classes, and modules to explain purpose, parameters, and return
   values

## When NOT to Comment

1. **Don't add comments that repeat the function name**

   ```python
   # Bad example
   # Determine the status
   status = determine_status(encounter)

   # Good example (no comment needed)
   status = determine_status(encounter)
   ```

2. **Don't comment obvious operations**

   ```python
   # Bad example
   # Increment the counter
   counter += 1

   # Good example (no comment needed)
   counter += 1
   ```

3. **Don't add comments for simple variable assignments**

   ```python
   # Bad example
   # Set the user's name
   user_name = "John"

   # Good example (no comment needed)
   user_name = "John"
   ```

## When to Comment

1. **Explain complex algorithms or business logic**

   ```python
   # Using Dijkstra's algorithm with a priority queue for better performance
   # This approach reduces time complexity from O(n²) to O(n log n)
   ```

2. **Document non-obvious side effects**

   ```python
   # This operation modifies the original list in-place and also updates the database
   process_items(items)
   ```

3. **Explain workarounds or unusual approaches**

   ```python
   # Using a sleep here to work around a race condition in the external API
   # See issue #1234 for details
   time.sleep(0.5)
   ```

4. **Clarify intent when the code might be confusing**

   ```python
   # We're using a negative index to efficiently get the last element
   # without having to calculate the length first
   last_item = items[-1]
   ```

## Docstring Guidelines

1. **Always include docstrings** for:

   - Modules
   - Classes
   - Public methods and functions

2. **Docstrings should include**:

   - Brief description of purpose
   - Parameters with types and descriptions
   - Return values with types and descriptions
   - Exceptions that might be raised
   - Examples for complex functions (when helpful)

3. **Follow consistent docstring style** (Google style preferred):

   ```python
   def process_data(data, options=None):
       """Process the input data according to specified options.

       Args:
           data: The input data to process
           options: Optional dictionary of processing options

       Returns:
           The processed data

       Raises:
           ValueError: If data is empty or invalid
       """
   ```

## Code Organization Instead of Comments

1. **Use descriptive variable and function names** instead of comments
2. **Extract complex logic** into well-named helper functions
3. **Use enums and constants** with descriptive names instead of magic numbers with comments

Remember that the best code is self-documenting. Comments should complement the code, not repeat it.
