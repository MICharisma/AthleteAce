# Testing AthleteAce

Specs are the executable record of what the app promises. Write one when it is the cheapest way to show a behavior works and to keep it working. A spec that can't fail, or that only repeats another spec, costs run time and reading time and protects nothing.

## Choose the layer

Use the lowest layer that can show the behavior. Each layer up is slower and breaks for more reasons.

| The behavior lives in | Spec type | Directory | Typical speed |
| --- | --- | --- | --- |
| A model, query, or service: rules, scopes, calculations, imports | model or service | `spec/models`, `spec/services` | milliseconds |
| A controller action: authorization, redirects, params, what the page or JSON contains | request | `spec/requests` | ~50 ms |
| A Stimulus controller or Turbo behavior: clicks, frames, streams, live updates, timers | interaction (rails-jsdom) | `spec/interactions` | ~100–300 ms |
| Layout: overflow, sizes, positions, breakpoints, anything needing real CSS | system (Chrome) | `spec/system/*_layout_spec.rb` | seconds |

Some quick rules for choosing:

- If the page works with JavaScript off, a request spec can check it. Use `response.parsed_body` (a Nokogiri document for HTML) and assert on elements, not on raw substrings of `response.body`.
- If you need to click something that a Stimulus controller or Turbo handles, write an interaction spec.
- Write a system spec only when the assertion is about geometry or computed style. System specs live in `spec/system/<feature>_layout_spec.rb`, hold no behavior checks, and use the helpers in `spec/support/layout.rb`: `phone_viewport`, `expect_no_horizontal_overflow`, and `rect(selector)`.

## Fixing a bug

1. Find the spec file that owns the behavior. It is usually named for the model, the controller, or the page. Extend that file rather than starting a new one.
2. Write an example that reproduces the bug at the lowest layer that shows it. Run it and watch it fail **for the reason the bug describes**. If it passes, or fails for another reason, you haven't reproduced the bug yet.
3. Fix the code and run the example again, then run the file.
4. Name the example for the rule that was broken ("hides pending posts from other visitors"), not for the bug report ("fixes #123").

## Writing an example

- **One behavior per example.** The name states the rule. If you'd describe it with "and", split it, unless the second half needs the first half's steps (for example, a filter that must survive the next page).
- **Arrange only what the behavior needs.** Use factories, and set only the attributes that matter to the assertion. Use `build` when nothing has to be saved. Use `let` for the subject and `before` for shared setup. Avoid `let!` unless the record must exist before the example runs and isn't referenced.
- **Assert outcomes, not implementation.** Check the record that changed, the response, or what the visitor sees. Don't stub the object under test. Stub only boundaries the test can't own: Rizz, Stripe, LLM providers, outside HTTP.
- **Prefer DAMP to DRY.** An example should read top to bottom without jumping to helpers. Extract a helper only when three or more examples share the same steps.
- **Make sure it can fail.** Before you finish, break the code it covers (flip a condition, change a constant, remove a line) and confirm the example fails. Restore the code. This takes a minute and catches most specs that test nothing.

## Don't write

- Screenshots, `save_screenshot`, or CDP calls in feature specs. Check a UI change in the browser at http://athleteace.test instead.
- `sleep`, retries, or `wait:` options. Interaction specs settle the page before every step. For timers, see below.
- One-liner association or validation matchers (`it { is_expected.to belong_to ... }`) unless the validation encodes a product rule. Then test the rule with real records.
- Specs that only check a page returns 200. Assert something the page promises.
- The same behavior at two layers. When an interaction spec covers a flow, its request spec doesn't need to repeat every assertion.
- `allow_any_instance_of`. Inject the dependency, or stub the class method that builds it.

## Interaction specs

Interaction specs use [rails-jsdom](https://github.com/jakehow/rails-jsdom). Rails renders real pages, the app's real Stimulus controllers and Turbo run in jsdom, and every request is answered by Rails in the test process. No browser and no server are involved. `spec/support/interactions.rb` adapts the gem's Minitest test case to RSpec, so every file under `spec/interactions/` gets the following:

- Navigation and forms: `visit`, `click`, `click_on`, `click_link`, `click_button`, `fill_in`, `select`, `check`, `choose`, `within`, `find`, `all`, `first`, `send_keys`, `evaluate_script`, `using_session`, `accept_confirm`.
- Matchers on `page` or on a found element: `have_css`, `have_content`, `have_field`, `have_button`, `have_link`, `have_current_path`, `have_title`. Each has a `have_no_` form.
- `sign_in ace` from Devise.
- A virtual clock. Ruby time is frozen when the example starts and pages share it. A timer due within a second runs before the next step. For a longer one, `travel 2.seconds` moves the page clock and runs it.

The gem has limits:

- There is no layout. Every element measures 0×0, so layout checks go in the feature's layout system spec.
- `matchMedia` never matches, observers never fire, and scrolling does nothing.
- CSS never applies, so text is the HTML source text: a heading styled uppercase still reads "Pacific Basketball League".
- Requests to other hosts fail. After the page loads, stub them with `stub_fetch`.
- A JavaScript error, an unhandled rejection, or an unexpected `confirm` fails the step. Wrap an expected dialog in `accept_confirm { ... }`.
- More than one element matching a locator raises. Scope with `within`, or pass `match: :first`.
- Run `npm install` once per checkout. The gem needs Node 22.22+, 24.15+, or 26+.

## Running specs

- `bundle exec rspec path/to/file_spec.rb` while working, then the related directory.
- `bundle exec rspec` before committing. The default run leaves out `:seed_library` examples.
- `bundle exec rspec --tag seed_library` when the seed data or the importer changes.
- `bundle exec rspec --only-failures` to rerun what failed.

When you run a filtered set, confirm the summary line shows the examples actually ran.
