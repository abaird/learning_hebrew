Next Project - better user management.

In this project, we have the following models:

Users have Decks...Decks have words...Words have glosses. This was done originally because I was going to create Anki decks for my vocabulary words. However, I want to be able to reuse words between decks, and I don't want words to be dependent on a deck existing. In the new paradigm, here's what I would like the model to look like:

Users have Decks...Words has many decks, decks have many words (many to many)

Words can have many glosses (still the same)

Or, to say it a different way, I want to be able to create words independently of decks and then assign as many words to a deck (or none!) as I want. The idea is that over time, a given user will have an ever expanding vocabulary that he/she adds to over time. Eventually (not now) we will build a custom dictionary based on a deck so that a user can have an interface to look up words that he/she already knows. It will basically be the index page for a deck. We won't build that now, we are just modifying the underlying datastructures to support it in the future.

Also, we need to add the idea of a superuser who is the entity that is responsible for adding words to the database (well, probably the words will be added via an import - but we'll get to that later). However, I want to add an admin or superuser user that is always present in the database so that I won't constantly have to adding a user to devise everytime the database re-initializes. I'd like to add that user via a database seed file. You can just make the superuser me (abaird@bairdsnet.net) and setup a password for me. We don't want to commit this to github, so I guess that will need to be a secret that's managed via google secrets. This might be a problem for our Tiltfile setup because in development we don't load secrets from Google Secrets - but I guess the superuser dev password doesn't really need to be a secret. Ha - you can just set the password to secret!.

Finally, we need to clean up some of the views in our application. If there is no user logged in, we should load the sign-in page. Also, it would be nice if that page had some styling other than just the barebones style that we currently have. If a user is logged in, it should display the user in the top right hand side. Also, when a user is logged in, there should be links to the decks, words and glosses page. Oh, well, actually, for superuser all 3 of those should be visible. But, for non superuser users, they would only have access to decks (all actions), words (limited to index and show), glosses (limited to index and show). Mabye also there should be a logoff button in the top right as well.

Please use Pundit (ruby gem) for permissions (since I use that at work and am familiar with it already).

Please think deeply on this task and write out the steps suitable for someone (or some AI) to follow later. Put together an implementation plan with steps. Once you are complete, ask for my approval and once I give it, write it out to a file projects/model_improvements.md.