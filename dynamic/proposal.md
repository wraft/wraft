# Product Design
Our Product Design approach is a combination of Lean UX principles, and Google Design Sprint, resulting in quick outcomes, and faster validations.

Our design process is split into 3 major parts:

## Discovery
Discovery involves conducting inquiry into types of potential users of the application. This involves Strategic Analysis and Planning, Information Architecture, Interaction with potential users and business owners, doing a competitive analysis of the product landscape, talking with stake owners to understand business objectives etc.

This includes, but not limited to following activities:

1. **User Research**\
We will hold discussions and interviews with business stakeholders and other relevant business user groups to clarify the business goals and identify supplemental user information. While also researching into various aspects of the users that we intent to cater.

2. **Competitive Analysis**\
We will review competitor apps to identify where LawStore needs to be positioned within the competitive landscape, work with the team to identify likes, dislikes, and opportunities in the space.

3. **Persona Development**\
Personas are documents that describe typical target users that helps making business decision easier. This is mostly derived out of talking with different sets of users of the application, or on a hypothetical basis.

## Define & Prototype
Based on the discovery, a usable interactive prototype of the application will be developed in close collaboration with LawStore. This enables both parties to put in thoughts and test practical implications and users perspective of the application. We'll test the applications flow, and usability in different aspects. This includes, but are not limited to following activities:

1. **User Journey Maps**\
A time-line of user actions that describes the relationship between your brand and your customers. We will visualise all of a user's interactions with your product, from their point of view.

2. **Information Architecture**\
With use of methods like Card Sorting, we will organise and prioritise contents within the application, making it easier for users to find relevant content.

3. **Wireframes & Prototype**\
We believe in early prototyping, and validating our assumptions from real users, with prototyping, we will have realistic understanding of how our users would interact with your application.

## Design and Validate
This phase involves building a fully functional design system, Business owners and potential users are given this to test our interactions and the feed backs are validated, and applied on the next iteration.

1. **Identity**\
We will hold discussions and interviews with business stakeholders and other relevant business user groups to clarify the business goals and identify supplemental user information. While also researching into various aspects of the users that we intent to cater.

2. **Visual Design**\
Based on defined characteristics of the brand, we will come up with different set of designs to put them into practice. To make design persistent - we build a system to bring in continuely - mostly through a set of scales for typopgraphy, spacing, and coloring. Our deliverable will include reusable, components, that makes future product design faster, and maintainable.

3. **Usability Testing**\
We will organise a set of potential users interact with the app, and take their inputs/feedbacks, also record their experiences.

# Technology Stack
Our team follows Extreme Programming principles, were our developers emphasis on pair-programing, write testable code and maintaining strict style guides. 

Our source codes are hosted at Gitlab and follow Semantic Versioning. You will be given access to the codebase from day 1, and would be able to access our commit logs. 

## Backend Development
We propose to develop the application as an API driven web app build with Elixir on top of  Phoenix Framework - a dynamic, functional language de-signed for building scalable and maintainable applications - with PostgreSQL as the primary database.

Building an API-first will allow the company to make the data available to multiple devices/clients in the future, like mobile and tablet apps.

The backend will also consume couple of services like Elasticsearch, Redis, Cassandra, RabbitMQ/Kafka etc, for providing faster and safer experience to the end user.

![image](./images/diagram-server.png){ width=100% }\

## Front-End Development
The customer facing part of the application will be built on top of ReactJS - a battletested technology - along with Redux, styled-components, Sagas, Webpack etc. 

