import '../models/video_model.dart';
import '../models/category_model.dart';

// Mock video data for kids content
final List<Video> mockVideos = [
  // Educational Videos
  Video(
    id: 'gG7uCskUOrA',
    title: 'How Do Airplanes Fly? | Science for Kids',
    thumbnailUrl: 'https://img.youtube.com/vi/gG7uCskUOrA/maxresdefault.jpg',
    channelTitle: 'Kids Learning Tube',
    publishedAt: '2023-05-15',
    description: 'Learn about the science of flight in this fun educational video for kids!',
    category: 'educational',
    videoUrl: 'https://www.youtube.com/watch?v=gG7uCskUOrA',
    duration: '8:24',
  ),
  Video(
    id: 'Ahg6qcgoay4',
    title: 'The Solar System Song | Planets for Kids',
    thumbnailUrl: 'https://img.youtube.com/vi/Ahg6qcgoay4/maxresdefault.jpg',
    channelTitle: 'Science Kids',
    publishedAt: '2023-06-20',
    description: 'A catchy song to help kids learn about all the planets in our solar system.',
    category: 'educational',
    videoUrl: 'https://www.youtube.com/watch?v=Ahg6qcgoay4',
    duration: '5:12',
  ),
  
  // Stories & Tales
  Video(
    id: 'TKEGv1qQ5qE',
    title: 'The Three Little Pigs | Fairy Tale Story',
    thumbnailUrl: 'https://img.youtube.com/vi/TKEGv1qQ5qE/maxresdefault.jpg',
    channelTitle: 'Story Time Kids',
    publishedAt: '2023-04-10',
    description: 'The classic tale of the three little pigs and the big bad wolf.',
    category: 'stories',
    videoUrl: 'https://www.youtube.com/watch?v=TKEGv1qQ5qE',
    duration: '10:45',
  ),
  Video(
    id: 'Yt8GFgxlITs',
    title: 'Goldilocks and the Three Bears',
    thumbnailUrl: 'https://img.youtube.com/vi/Yt8GFgxlITs/maxresdefault.jpg',
    channelTitle: 'Bedtime Stories',
    publishedAt: '2023-03-25',
    description: 'A wonderful bedtime story about Goldilocks and her adventure.',
    category: 'stories',
    videoUrl: 'https://www.youtube.com/watch?v=Yt8GFgxlITs',
    duration: '12:30',
  ),
  
  // Arts & Crafts
  Video(
    id: '1Vs9xqNKgYc',
    title: 'How to Draw a Cute Puppy | Easy Drawing for Kids',
    thumbnailUrl: 'https://img.youtube.com/vi/1Vs9xqNKgYc/maxresdefault.jpg',
    channelTitle: 'Art for Kids Hub',
    publishedAt: '2023-07-05',
    description: 'Learn to draw an adorable puppy step by step!',
    category: 'arts',
    videoUrl: 'https://www.youtube.com/watch?v=1Vs9xqNKgYc',
    duration: '7:18',
  ),
  Video(
    id: 'qNw8I6n3aTk',
    title: 'DIY Paper Butterfly Craft | Fun Craft for Kids',
    thumbnailUrl: 'https://img.youtube.com/vi/qNw8I6n3aTk/maxresdefault.jpg',
    channelTitle: 'Crafty Kids',
    publishedAt: '2023-06-12',
    description: 'Make beautiful paper butterflies with simple materials!',
    category: 'arts',
    videoUrl: 'https://www.youtube.com/watch?v=qNw8I6n3aTk',
    duration: '9:42',
  ),
  
  // Music & Songs
  Video(
    id: '_UR-l3QI2nE',
    title: 'ABC Song | Alphabet Song for Kids',
    thumbnailUrl: 'https://img.youtube.com/vi/_UR-l3QI2nE/maxresdefault.jpg',
    channelTitle: 'Super Simple Songs',
    publishedAt: '2023-02-14',
    description: 'Learn the alphabet with this fun and catchy ABC song!',
    category: 'music',
    videoUrl: 'https://www.youtube.com/watch?v=_UR-l3QI2nE',
    duration: '3:45',
  ),
  Video(
    id: 'D0Ajq682yrA',
    title: 'Baby Shark Dance | Kids Songs',
    thumbnailUrl: 'https://img.youtube.com/vi/D0Ajq682yrA/maxresdefault.jpg',
    channelTitle: 'Pinkfong Kids',
    publishedAt: '2023-01-20',
    description: 'Dance along to the popular Baby Shark song!',
    category: 'music',
    videoUrl: 'https://www.youtube.com/watch?v=D0Ajq682yrA',
    duration: '4:20',
  ),
  
  // Animals & Nature
  Video(
    id: 'aMmAsqtGRmk',
    title: 'Amazing Animals for Kids | Wildlife Documentary',
    thumbnailUrl: 'https://img.youtube.com/vi/aMmAsqtGRmk/maxresdefault.jpg',
    channelTitle: 'National Geographic Kids',
    publishedAt: '2023-08-01',
    description: 'Discover amazing animals from around the world!',
    category: 'animals',
    videoUrl: 'https://www.youtube.com/watch?v=aMmAsqtGRmk',
    duration: '15:30',
  ),
  Video(
    id: 'wTcNtgA6gHs',
    title: 'Ocean Animals for Kids | Sea Creatures',
    thumbnailUrl: 'https://img.youtube.com/vi/wTcNtgA6gHs/maxresdefault.jpg',
    channelTitle: 'Ocean Explorers',
    publishedAt: '2023-07-18',
    description: 'Explore the wonderful world of ocean animals!',
    category: 'animals',
    videoUrl: 'https://www.youtube.com/watch?v=wTcNtgA6gHs',
    duration: '11:25',
  ),
  
  // Fun & Games
  Video(
    id: 'BQ9q4U2P3ig',
    title: 'Brain Teasers and Riddles for Kids',
    thumbnailUrl: 'https://img.youtube.com/vi/BQ9q4U2P3ig/maxresdefault.jpg',
    channelTitle: 'Fun Learning',
    publishedAt: '2023-05-30',
    description: 'Test your brain with these fun riddles and puzzles!',
    category: 'games',
    videoUrl: 'https://www.youtube.com/watch?v=BQ9q4U2P3ig',
    duration: '8:50',
  ),
  
  // Cartoons
  Video(
    id: 'kUj0m4E6kSg',
    title: 'Peppa Pig Full Episodes | Kids Cartoons',
    thumbnailUrl: 'https://img.youtube.com/vi/kUj0m4E6kSg/maxresdefault.jpg',
    channelTitle: 'Peppa Pig Official',
    publishedAt: '2023-04-22',
    description: 'Watch fun episodes of Peppa Pig!',
    category: 'cartoons',
    videoUrl: 'https://www.youtube.com/watch?v=kUj0m4E6kSg',
    duration: '20:15',
  ),
  
  // Sports & Activities
  Video(
    id: 'dhCM0C6GnrY',
    title: 'Kids Yoga and Exercise | Fun Workout',
    thumbnailUrl: 'https://img.youtube.com/vi/dhCM0C6GnrY/maxresdefault.jpg',
    channelTitle: 'Cosmic Kids Yoga',
    publishedAt: '2023-06-08',
    description: 'A fun yoga and exercise session for kids!',
    category: 'sports',
    videoUrl: 'https://www.youtube.com/watch?v=dhCM0C6GnrY',
    duration: '14:20',
  ),
];
