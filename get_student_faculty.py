#! /usr/bin/python
import sys
import json
import mysql.connector
import argparse

#-------------------------------------------------------------------------------
# simple DB class
#-------------------------------------------------------------------------------

class DB_Connector(object):

  def __init__(self, user, password, host, database):
    self.user = user
    self.password = password
    self.host = host
    self.database = database
    self.cnx = None # The connection object
    self.cursor = None # The cursor object

    self.CreateConnection()

  def CreateConnection(self):

    try:
      self.cnx = mysql.connector.connect(user=self.user,
                                               password=self.password,
                                               host=self.host,
                                               database=self.database)
      self.cursor = self.cnx.cursor()
      # print("Connected to the database")
    except mysql.connector.Error as e:
      print(e)

  def Execute(self, sql):

    try:
      self.cursor.execute(sql)
      return self.cursor.fetchall()

    except mysql.connector.Error as err:
      # Handle any errors from the query
      print("Failed to execute query: {}".format(err))
      return None

  # Close the cursor and the connection
  def close(self):
    self.cursor.close()
    self.cnx.close()

def get_args():
  parser = argparse.ArgumentParser(description='''
  # example : python {} --studentid 1'''.format(sys.argv[0]))

  parser.add_argument("-id",
  "--studentid",
  required=True,
  action='store',
  help='passing student  id',
  )

  args = parser.parse_args()
  return args

args = get_args()
student_id = args.studentid

def getDB_college():
  config = {
    'user': 'demoapp',
    'password': 'ahH0iTha@!',
    'host': 'localhost',
    'database': 'college',
  }

  db = DB_Connector(**config)
  return db

def get_student_faculty(student_id):

  sql = "SELECT faculty_id from student  WHERE id = '{}'".format(student_id)
  db = getDB_college()
  result = db.Execute(sql)
  for row in result:
    faculty_id = row[0]
    return faculty_id

def get_facultyname_by_id(faculty_id):
  sql = "SELECT name from faculty  WHERE id = '{}'".format(faculty_id)
  db = getDB_college()
  result = db.Execute(sql)
  for row in result:
    name = row[0]
    return name

def main():
  faculty_id = get_student_faculty(student_id)
  faculty_name = get_facultyname_by_id(faculty_id)
  print(faculty_name)


if __name__ == "__main__":
  main()