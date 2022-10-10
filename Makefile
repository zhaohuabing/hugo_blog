serve:
	hugo serve --bind 0.0.0.0 --disableFastRender
index-algolia:
	hugo
	npm run algolia
index-pagefind:
	hugo
	rm -rf public/_pagefind
	rm -rf static/_pagefind
	npx pagefind --source public
	cp -r public/_pagefind static/_pagefind
index-pagefind:
deploy: # deploy command for netlify. 
	hugo
	# npx pagefind --source public
	# Notice: these environment variables need to be set: ALGOLIA_ADMIN_KEY, ALGOLIA_APP_ID, ALGOLIA_INDEX_FILE, ALGOLIA_INDEX_NAME
	npm install atomic-algolia --save
	npm run algolia 

.PHONY: serve index-algolia index-pagefind deploy