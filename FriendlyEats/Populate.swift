//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import FirebaseFirestore

extension Firestore {

  /// Returns a reference to the top-level users collection.
  var users: CollectionReference {
    return self.collection("users")
  }

  /// Returns a reference to the top-level restaurants collection.
  var restaurants: CollectionReference {
    return self.collection("restaurants")
  }

  /// Returns a reference to the top-level reviews collection.
  var reviews: CollectionReference {
    return self.collection("reviews")
  }

  /// Returns a reference to the top-level yums collection.
  var yums: CollectionReference {
    return self.collection("yums")
  }

  /// Returns a tuple of arrays containing sample data to populate the app.
  func sampleData() -> (users: [User], restaurants: [Restaurant], reviews: [Review], yums: [Yum]) {
    let userCount = 20
    let restaurantCount = 20
    let reviewCountPerRestaurant = 20
    let maxYumCountPerReview = 20 // This must be less than or equal to the number of users,
    // since yums are unique per user per review. If this number
    // exceeds the number of users, the code will likely crash
    // when generating likes.

    // Users must be created first, since Restaurants have dependencies on users,
    // Reviews depend on both Users and Restaurants, and Yums depend on Reviews and Users.
    // The users generated here will not be backed by real users in Auth, but that's ok.
    let users: [User] = (0 ..< userCount).map { _ in
      let uid = UUID().uuidString
      return User(userID: uid)
    }

    func randomUser() -> User { return users[Int(arc4random_uniform(UInt32(userCount)))] }

    var restaurants: [Restaurant] = (0 ..< restaurantCount).map { _ in
      let ownerID = randomUser().userID
      let restaurantID = UUID().uuidString
      let name = Restaurant.randomName()
      let category = Restaurant.randomCategory()
      let city = Restaurant.randomCity()
      let price = Restaurant.randomPrice()
      let photoURL = Restaurant.randomPhotoURL()

      return Restaurant(restaurantID: restaurantID,
                        ownerID: ownerID,
                        name: name,
                        category: category,
                        city: city,
                        price: price,
                        reviewCount: 0,   // This is modified later when generating reviews.
        averageRating: 0, // This is modified later when generating reviews.
        photoURL: photoURL)
    }

    var reviews: [Review] = []
    for i in 0 ..< restaurants.count {
      var restaurant = restaurants[i]
      reviews += (0 ..< reviewCountPerRestaurant).map { _ in
        let reviewID = UUID().uuidString
        let rating = RandomUniform(5) + 1
        let userInfo = randomUser()
        let text: String
        let date = Date()
        let restaurantID = restaurant.restaurantID

        switch rating {
        case 5:
          text = "Amazing!!"
        case 4:
          text = "Tasty restaurant, would recommend"
        case 3:
          text = "Food was good but the service was slow"
        case 2:
          text = "The ketchup was too spicy"
        case 1:
          text = "There is a bug in my soup"
        case _:
          fatalError("Unreachable code. If the app breaks here, check the call to RandomUniform above.")
        }

        // Compute the new average after the review is created. This adds side effects to the map
        // statement, angering programmers all over the world
        restaurant.averageRating =
          (restaurant.averageRating * Float(restaurant.reviewCount) + Float(rating))
          / (restaurant.averageRating + 1)
        restaurant.reviewCount += 1

        // Since everything here is value types, we need to explicitly write back to the array.
        restaurants[i] = restaurant

        return Review(reviewID: reviewID,
                      restaurantID: restaurantID,
                      rating: rating,
                      userInfo: userInfo,
                      text: text,
                      date: date,
                      yumCount: 0) // This will be modified later when generating Yums.
      }
    }

    var yums: [Yum] = []
    for i in 0 ..< reviews.count {
      var review = reviews[i]
      let numYums = RandomUniform(maxYumCountPerReview)
      if numYums == 0 { continue }

      yums += (0 ..< numYums).map { index in
        let reviewID = review.reviewID

        // index is guaranteed to be less than the number of users.
        // Use an index here instead of a random users so users don't
        // double-like restaurants, since that's supposed to be illegal.
        let userID = users[index].userID

        review.yumCount += 1
        reviews[i] = review

        return Yum(userID: userID, reviewID: reviewID)
      }
    }

    return (
      users: users,
      restaurants: restaurants,
      reviews: reviews,
      yums: yums
    )
  }

  // Writes data directly to the Firestore root. Useful for populating the app with sample data.
  func prepopulate(users: [User], restaurants: [Restaurant], reviews: [Review], yums: [Yum]) {
    let batch = self.batch()

    users.forEach {
      let dictionary = $0.dictionary
      let document = self.users.document($0.userID)
      batch.setData(dictionary, forDocument: document)
    }

    restaurants.forEach {
      let dictionary = $0.dictionary
      let document = self.restaurants.document($0.restaurantID)
      batch.setData(dictionary, forDocument: document)
    }

    reviews.forEach {
      let dictionary = $0.dictionary
      let document = self.reviews.document($0.reviewID)
      batch.setData(dictionary, forDocument: document)
    }

    yums.forEach {
      let dictionary = $0.dictionary
      let document = self.yums.document()
      batch.setData(dictionary, forDocument: document)
    }

    batch.commit { error in
      if let error = error {
        print("Error populating Firestore: \(error)")
      }
    }
  }

  // Pre-populates the app with sample data.
  func prepopulate() {
    let data = sampleData()
    prepopulate(users: data.users,
                restaurants: data.restaurants,
                reviews: data.reviews,
                yums: data.yums)
  }

}
