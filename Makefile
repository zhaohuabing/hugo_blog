serve:
	hugo serve --bind 0.0.0.0 --disableFastRender
index:
	hugo
	npm run algolia
deploy: # deploy command for netlify 
	npm install atomic-algolia --save
	hugo
	npm run algolia 

.PHONY: serve index deploy

