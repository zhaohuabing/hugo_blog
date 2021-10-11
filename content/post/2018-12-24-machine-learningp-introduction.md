---
layout:     post

title:      "Machine Learning Introduction"
subtitle:   "Machine Learning-Week 1"
excerpt: ""
author:     "赵化冰"
date:       2018-12-24
description: ""
image: "/img/2018-12-24-machine-learningp-introduction/background.jpg"
published: true 
tags:
    - Machine Learning 
    - Supervised learning

categories: [ Tech ]
---

# What is machine learning?

Two definitions of machine learning are offered.

Arthur Samuel version: <BR>
A field of study that gives computers the ability to *learn without being explicitly programmed*.    
 
Tom Mitchell version: <BR>
A computer program is said to learn from experience E with respect to some task T and some performance measure P, if its performance on T, as measured by P, improves with experience E. 

Example: playing checkers.

E = the experience of playing many games of checkers

T = the task of playing checkers.

P = the probability that the program will win the next game.

# Machine learning algorithms

In general, any machine learning problem can be assigned to one of two broad classifications:

* Supervised learning
* Unsupervised learning

There are also some others: Reinforcement learning, Recommender  system

## Supervised learning

Supervised learning is the machine learning task of learning a function that maps an input to an output based on example input-output pairs. It infers a function from labeled training data consisting of a set of training examples, *for every example in the training data set, the correct answer is already given*.

There are two types of supervised learning problems:

### Regression problem

In a regression problem, the supervised learning algorithm is trying to predict results within a continuous output, meaning that it is trying to map input variables to some continuous function. 

**Example**

Given data about the size of houses on the real estate market, try to predict their price. Price as a function of size is a continuous output, so this is a regression problem.
![](/img/2018-12-24-machine-learningp-introduction/regression-problem-house-price.png)
<center>House Price Prediction</center>

### Classification problem 

In a classification problem, the supervised learning algorithm is instead trying to predict results within a discrete output, meaning that it is trying to map input variables to discrete categories. 

**Example**

Classification - Given a patient with a tumor, we have to predict whether the tumor is malignant or benign.

![](/img/2018-12-24-machine-learningp-introduction/classification-problem-breast-cancer-one-feature.png)
<center>Breast cancer prediction with one feature</center>
![](/img/2018-12-24-machine-learningp-introduction/classification-problem-breast-cancer-two-features.png)
<center>Breast cancer prediction with two features</center>

## Unsupervised learning

TBC

# Reference 

Free online course offered by Stanford: https://www.coursera.org/learn/machine-learning
