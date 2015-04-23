# Eloono
####Better Twitter Follow Recommendations

Eloono is an ongoing attempt at creating a better Twitter follow "recommender".

I've worked to keep things geared design wise for use on a smart phone.

Interaction with the Twitter API is all handled by [Adam Green's fantastic open source Twitter engagement code](http://140dev.com/twitter-api-engagement-programming/source-code/) whose base code is leveraged extensivly for all Tweet collection. 

Follow recommendations are made based primarily on interaction counts and number of mutual connections.

Currently, Eloono sends one email per day with the highest scoring recommendation which can either be "followed" or ignored. From there, Eloono will take you to the web view where the next highest scored recommended follow can be seen. The web view allows for swiping left to ignore and swiping right to follow.

Plenty more to do including categorization of people you follow, clean up of web interface, and text based matching to favor recommendations who Tweet on topics of interest more frequently.
