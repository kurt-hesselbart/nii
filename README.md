# nii (Nearly Instant Instances)

If you need to jump to specific strings or regexps regularly, you probably use standard search functions.
But it could be more convenient to jump independently of the standard search routine.

Perhaps you use occur, which has the disadvantage to act on lines not on true occurences.

An instance (in the manner of nii) is an occurence enhanced by a definition of the position of point after reaching the occurence.

After setting up a set of instances, described by strings or regular expressions,
you can choose shortly an instance for navigating similar to functions like ‘forward-paragraph’.

The word instances is used (in the documentation as well as in the names of the functions) to avoid the work occurrence,
which could mislead to think of a relationship to the occur functions.

The set of instances is arranged in an alist, where the key is the instance name.
The value has three elements.
The first element is a regular expression or a list which contains one or more strings representing the search item.
The second and third element represent information about the behaviour of point after reaching the item.

There is a bunch of functions helping to maintain the set of instances, see ‘nii-maintain-instances’.

You can set up the package like this:

```elisp
(require 'nii)
(global-set-key (kbd "M-a") #'nii-forward-instance)
(global-set-key (kbd "M-e") #'nii-backward-instance)
(global-set-key (kbd "C-x M-a") #'nii-maintain-instances)
```

nii is written with the use of a completion framework (such as ido, ivy or helm) in mind,
so it could be less convenient to choose an instance without such a framework.

The user can use the customization tool to maintain the instances, but I prefer using ‘nii-maintain-instances’.

Per default the alist holding the instances will be saved to the custom.
It's recommended to use a distinct file by filling variable ‘nii-instances’.

## TODO

Tthe variable holding the instances are stored to the custom.
It has been done, because it is available at every emacs configuration.
There should be a option to store to a distinct file.

The pointer variable isn't stored between sessions.

The editing of the strings means to reenter all strings from scratch, this isn't very comfortable.

nii works only in the current buffer, it should be possible to search in all buffers, or releated buffers.
projectile integration should be fine.
