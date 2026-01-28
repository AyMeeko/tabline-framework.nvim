I want to add functionality to this plugin.

Right now, if you open more tabs than can reasonably fit in the window, it renders the bar such that the overflow to the right move off screen.

I want to change the behavior to introduce a sliding viewport of tabs. Let's talk about some examples of how this would work.

Example 1:

1. user opens vim with one tab. The tab bar should not be shown yet.
2. user opens another file in a tab to the right (tab 2). The tab bar renders both tabs, where the right-most one is the active one.
3. user opens another file in a tab to the right (tab 3). This time, however, all of the tabs do not fit in the viewport. The plugin should slide the viewport so that the entirety of tab 3 is shown and the tab bar overflows to the left.
4. user navigates one tab to the left (to tab 2) and, since it's already rendered in the viewport, nothing changes with the tab bar.
5. user navigates one more tab to the left (to tab 1) and the viewport should shift so that the entirety of tab 1 is shown and the tab bar overflows to the right.


Do you have any questions?

