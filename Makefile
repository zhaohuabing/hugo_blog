serve:
	hugo serve --bind 0.0.0.0 --disableFastRender
index:
	hugo
	npm run algolia
deploy: # deploy command for netlify. Notice: these environment variables need to be set: ALGOLIA_ADMIN_KEY, ALGOLIA_APP_ID, ALGOLIA_INDEX_FILE, ALGOLIA_INDEX_NAME 
	npm install atomic-algolia --save
	hugo
	npm run algolia 

.PHONY: serve index deploy