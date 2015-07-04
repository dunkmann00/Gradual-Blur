# Gradual-Blur
Gradually blur background content.


<img src="/Gradual Blur/ScreenCapture.gif" align="right">
A GWGradualBlurView object provides a way to add a blur over views that gradually animates onto the screen.
 
The view takes a snapshot of what is behind it and applies the blur to that snapshot. If you want the view to update the snapshot of what is behind it you can call the refreshBackground method. Since the GWGradualBlurView is used to provide an overlay on top of content that is in the "background," there usually is not too many changes going on. This is why the static snapshot of what is behind the blurred view is still an effective way to represent what is actually behind the view. However, if changes do occur you can easily update the background to represent those changes. The view is capable of handling the refresh with good performance but would not be able to if it was being updated in real time.

The Xcode project in the repository has a working example of the gradual blur in use. When you tap the photo that was selected from your photo library the blur will animate onto (or off) the screen. Tapping the button on the bottom allows you to change the picture you selected.
