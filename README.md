# Rspamd Docker image 📨 🐋

## Usage

~~~
mkdir dbdir
sudo chown 11333:11333 dbdir
docker run -v `pwd`/dbdir:/var/lib/rspamd -ti rspamd/rspamd
~~~

## Acknowledgements

The Fasttext [language identification model](https://fasttext.cc/docs/en/language-identification.html) used in this image is distributed under the [Creative Commons Attribution-Share-Alike License 3.0](https://creativecommons.org/licenses/by-sa/3.0/).
